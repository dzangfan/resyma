require "resyma/core/automaton"

class String
  include Resyma::Core::Matchable

  def match_with_value?(other)
    self == other
  end

  def identity_with_matchable?(other)
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
