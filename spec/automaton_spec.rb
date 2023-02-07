require "set"
require "resyma/core/automaton"
require "resyma/core/utilities"

class String
  include Resyma::Core::Matchable

  def match_with_value?(other)
    self == other
  end
end

RSpec.describe Resyma::Core::Automaton do
  it "works with literal matcher" do
    ab = Resyma::Core::AutomatonBuilder.new
    states = (0...3).map { ab.new_state! }
    ab.accept!(states[1])
    ab.accept!(states[2])
    ab.start!(states[0])
    ab.add_transition!(states[0], "a", states[0])
    ab.add_transition!(states[0], "b", states[1])
    ab.add_transition!(states[0], "c", states[2])
    ab.add_transition!(states[2], "b", states[1])
    automaton = ab.build
    expect(automaton).to be_a Resyma::Core::Automaton
    expect(automaton.start).to be states[0]
    expect(automaton.accept?(states[1])).to be true
    expect(automaton.accept?(states[2])).to be true
    expect(automaton.destination(states[0], "a")).to be states[0]
    expect(automaton.destination(states[0], "b")).to be states[1]
    expect(automaton.destination(states[0], "c")).to be states[2]
    expect(automaton.destination(states[2], "b")).to be states[1]
    expect(automaton.destination(states[0], "d")).to be_nil
    expect(automaton.destination(states[1], "b")).to be_nil
    expect(automaton.destination(states[2], "c")).to be_nil
  end
end

RSpec.describe Resyma::Core::Epsilon do
  it "has unique value epsilon" do
    expect(Resyma::Core::Epsilon).to be(Resyma::Core::Epsilon)
    expect(Resyma::Core::Epsilon).not_to be("epsilon")
  end

  ab = Resyma::Core::AutomatonBuilder.new
  states = (0...7).map { ab.new_state! }
  ab.start! states[0]
  ab.accept! states[5]
  ab.accept! states[6]
  ab.add_transition!(states[0], Resyma::Core::Epsilon, states[1])
  ab.add_transition!(states[0], Resyma::Core::Epsilon, states[3])
  ab.add_transition!(states[1], Resyma::Core::Epsilon, states[2])
  ab.add_transition!(states[3], "a", states[4])
  ab.add_transition!(states[2], Resyma::Core::Epsilon, states[5])
  ab.add_transition!(states[4], "b", states[5])
  ab.add_transition!(states[4], Resyma::Core::Epsilon, states[6])
  a = ab.build

  it "computes epsilon-closure" do
    expect(a.eclose(Set[states[0]])).to eq(Set[states[0], states[1], states[2],
                                               states[3], states[5]])
    expect(a.eclose(Set[states[1]])).to eq(Set[states[1], states[2], states[5]])
    expect(a.eclose(Set[states[2]])).to eq(Set[states[2], states[5]])
    expect(a.eclose(Set[states[3]])).to eq(Set[states[3]])
    expect(a.eclose(Set[states[4]])).to eq(Set[states[4], states[6]])
    expect(a.eclose(Set[states[5]])).to eq(Set[states[5]])
    expect(a.eclose(Set[states[6]])).to eq(Set[states[6]])
  end

  it "can be converted to non-epsilon automaton" do
    d = a.to_DFA
    expect(a.has_epsilon?).to be true
    expect(d.has_epsilon?).to be false
  end

  it "handles DFA containing common prefix properly" do
    ab = Resyma::Core::AutomatonBuilder.new
    states = (0...7).map { ab.new_state! }
    ab.start! states[0]
    ab.accept! states[6]
    ab.accept! states[5]
    ab.add_transition!(states[0], Resyma::Core::Epsilon, states[1])
    ab.add_transition!(states[0], Resyma::Core::Epsilon, states[2])
    ab.add_transition!(states[1], "a", states[3])
    ab.add_transition!(states[2], "a", states[4])
    ab.add_transition!(states[4], "b", states[5])
    ab.add_transition!(states[3], "c", states[6])
    d = ab.build.to_DFA
    expect(Resyma::Core::Utils.automaton_accept?(d, %w[a c])).to be true
    expect(Resyma::Core::Utils.automaton_accept?(d, %w[a b])).to be true
    expect(Resyma::Core::Utils.automaton_accept?(d, %w[a])).to be false
    expect(Resyma::Core::Utils.automaton_accept?(d, %w[])).to be false
  end

  it "denotes the same language with the non-epsilon version" do
    d = a.to_DFA
    try = proc do |sample, result|
      expect(Resyma::Core::Utils.automaton_accept?(d, sample)).to be result
    end
    try.call [], true
    try.call %w[a], true
    try.call %w[b], false
    try.call %w[a b], true
    try.call %w[b a], false
  end
end

RSpec.describe Resyma::Core::Regexp do
  include Resyma::Core::RegexpOp

  def try(regexp, input, result)
    automaton = regexp.to_automaton
    answer = Resyma::Core::Utils.automaton_accept?(automaton, input)
    expect(answer).to be result
  end

  it "works with empty regexp" do
    try(reps, [], true)
    try(reps, ["a"], false)
  end

  it "works with literal regexp" do
    try(rchr("a"), ["a"], true)
    try(rchr("a"), [], false)
    try(rchr("a"), ["b"], false)
  end

  it "works with choices" do
    try(ror(rchr("a"), rchr("A")), %w[a], true)
    try(ror(rchr("a"), rchr("A")), %w[A], true)
    try(ror(rchr("a"), rchr("A")), %w[^], false)
    try(ror(rchr("a"), rchr("A"), rchr("^")), %w[^], true)
    try(ror(rchr("a")), %w[a], true)
    try(ror(rchr("a"), reps), %w[a], true)
    try(ror(rchr("a"), reps), [], true)
    try(ror(rchr("a"), reps), %w[A], false)
  end

  it "works with sequences" do
    try(rcat(rchr("a"), rchr("b"), rchr("c")), %w[a b c], true)
    try(rcat(rchr("a"), rchr("b"), rchr("c")), %w[a 6 c], false)
    try(rcat(rchr("a"), ror(rchr("b"), rchr("B")), rchr("c")), %w[a b c], true)
    try(rcat(rchr("a"), ror(rchr("b"), rchr("B")), rchr("c")), %w[a B c], true)
    try(rcat(rchr("a"), ror(rchr("b"), reps), rchr("c")), %w[a b c], true)
    try(rcat(rchr("a"), ror(rchr("b"), reps), rchr("c")), %w[a c], true)
    try(rcat(rchr("a"), reps, rchr("b")), %w[a b], true)
  end

  it "works with loops" do
    try(rrep(rchr("a")), [], true)
    try(rrep(rchr("a")), %w[a], true)
    try(rrep(rchr("a")), %w[a a], true)
    try(rrep(rchr("a")), %w[a a a a a a a], true)
  end

  def yes(re, inp)
    try(re, inp.split(""), true)
  end

  def no(re, inp)
    try(re, inp.split(""), false)
  end

  it "works with complex case 1" do
    re = rcat(rchr("a"), rrep(ror(rchr("a"), rchr("b"))), rchr("a"))
    yes(re, "aa")
    yes(re, "aaa")
    yes(re, "aba")
    yes(re, "aaaa")
    yes(re, "aaba")
    yes(re, "abaa")
    yes(re, "abba")
    no(re, "")
    no(re, "abbab")
    no(re, "a")
    no(re, "bab")
  end

  it "works with complex case 2" do
    re = rrep(rcat(ror(reps, rchr("a")), rrep(rchr("b"))))
    yes(re, "")
    yes(re, "a")
    yes(re, "ababab")
  end

  it "works with complex case 3" do
    re = rcat(rrep(ror(rchr("a"), rchr("b"))), rchr("a"),
              ror(rchr("a"), rchr("b")), ror(rchr("a"), rchr("b")))
    yes(re, "ababaaaa")
    yes(re, "aaa")
    no(re, "")
    no(re, "aa")
    no(re, "baa")
    no(re, "abbaabaa")
  end
end
