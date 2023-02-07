require "resyma/core/algorithm"
require "resyma/core/parsetree"
require "resyma/core/automaton"

RSpec.describe Resyma::Core::PTNodeMatcher do
  zero = Resyma::Core::ParseTreeBuilder.root(:number, "0").build
  zeus = Resyma::Core::ParseTreeBuilder.root(:string, "Zeus").build
  plus = Resyma::Core::ParseTreeBuilder.root(:plus) do
    leaf(:number, "0")
    leaf(:op, "+")
    leaf(:string, "Zeus")
  end.build

  it "matches nodes with specific type and arbitrary value" do
    matcher = Resyma::Core::PTNodeMatcher.new(:number)
    expect(matcher.match_with_value?(zero)).to be true
    expect(matcher.match_with_value?(zeus)).to be false
    expect(matcher.match_with_value?(plus)).to be false
    matcher = Resyma::Core::PTNodeMatcher.new(:plus)
    expect(matcher.match_with_value?(zero)).to be false
    expect(matcher.match_with_value?(zeus)).to be false
    expect(matcher.match_with_value?(plus)).to be true
  end

  it "matches nodes with both type and value" do
    matcher_zero = Resyma::Core::PTNodeMatcher.new(:number, "0")
    matcher_mysterious = Resyma::Core::PTNodeMatcher.new(:number, "Zeus")
    matcher_error = Resyma::Core::PTNodeMatcher.new(:plus, "+")
    expect(matcher_zero.match_with_value?(zero)).to be true
    expect(matcher_zero.match_with_value?(zeus)).to be false
    expect(matcher_zero.match_with_value?(plus)).to be false
    expect(matcher_mysterious.match_with_value?(zero)).to be false
    expect(matcher_mysterious.match_with_value?(zeus)).to be false
    expect(matcher_mysterious.match_with_value?(plus)).to be false
    expect(matcher_error.match_with_value?(zero)).to be false
    expect(matcher_error.match_with_value?(zeus)).to be false
    expect(matcher_error.match_with_value?(plus)).to be false
  end
end

RSpec.describe Resyma::Core::Engine do
  it "computes the right-most path for trees with single node" do
    tree = Resyma::Core::ParseTreeBuilder.root(:foo).build
    engine = Resyma::Core::Engine.new([])
    rmp = engine.RMP(tree)
    expect(rmp).to be_a Set
    expect(rmp.length).to eq 1
    expect(rmp.map(&:symbol)).to eq [:foo]
  end

  it "computes the right-most path for trees with multiple nodes" do
    tree = Resyma::Core::ParseTreeBuilder.root(0) do
      node 1 do
        leaf(2, nil)
        node 3 do
          leaf(4, nil)
          leaf(5, nil)
        end
      end
      node 6 do
        leaf(7, nil)
        node 8 do
          node 9 do
            leaf(10, nil)
          end
        end
        leaf(11, nil)
      end
    end.build
    engine = Resyma::Core::Engine.new([])
    rmp = engine.RMP(tree)
    expect(rmp).to be_a Set
    expect(rmp.map(&:symbol)).to eq [0, 6, 11]
  end

  parsetree = {}

  parsetree[:case_1] = Resyma::Core::ParseTreeBuilder.root(:expr) do
    leaf(:left, "(")
    node(:args) do
      node(:args) do
        node(:args) do
          node(:expr) do
            node(:literal) do
              leaf(:sym, "point")
            end
          end
        end
        node(:expr) do
          node(:literal) do
            leaf(:num, "0")
          end
        end
      end
      node(:expr) do
        node(:literal) do
          leaf(:num, "0")
        end
      end
    end
    leaf(:right, ")")
  end.build

  parsetree[:case_2] = Resyma::Core::ParseTreeBuilder.root(:expr) do
    node(:call) do
      leaf(:symbol, "graph")
      node(:block) do
        leaf(:left_curly, "{")
        node(:exprs) do
          node(:expr) do
            node(:binary) do
              node(:expr) { leaf(:symbol, "A") }
              leaf(:equal, "==")
              node(:expr) { leaf(:symbol, "B") }
            end
          end
          leaf(:semi, ";")
          node(:exprs) do
            node(:expr) do
              node(:binary) do
                node(:expr) { leaf(:symbol, "A") }
                leaf(:equal, "==")
                node(:expr) do
                  node(:call) do
                    leaf(:symbol, "C")
                    node(:args) do
                      node(:expr) do
                        node(:hash) do
                          leaf(:left_curly, "{")
                          node(:pair) do
                            leaf(:string, "color")
                            leaf(:arrow, "=>")
                            leaf(:string, "'blue'")
                          end
                          leaf(:right_curly, "}")
                        end
                      end
                    end
                  end
                end
              end
            end
            leaf(:semi, ";")
          end
        end
        leaf(:right_curly, "}")
      end
    end
  end.build

  include Resyma::Core::RegexpOp

  def node(type, value = nil)
    matcher = Resyma::Core::PTNodeMatcher.new(type, value)
    rchr(matcher)
  end

  def algorithm(tree, *automata)
    engine = Resyma::Core::Engine.new(automata)
    tree.clear!
    engine.traverse!(tree)
    [engine, engine.accepted_tuples(tree)]
  end

  it "works on single automaton - Episode 1" do
    automaton = rcat(
      node(:left),
      node(:sym, "point"), node(:num), node(:num),
      node(:right)
    ).to_automaton
    engine, accepted_set = algorithm(parsetree[:case_1], automaton)
    expect(accepted_set.length).to eq 1
    tuple4 = accepted_set.to_a.shift
    dns = engine.backtrack_for(parsetree[:case_1], tuple4)
    expect(dns.map(&:p_)).to eq [1, 7, 10, 13, 14]
    expect(dns.map(&:belongs_to).to_set).to eq Set[0]
  end

  it "works on single automaton - Episode 2" do
    automaton = rcat(
      node(:left),
      node(:expr), rrep(node(:expr)),
      node(:right)
    ).to_automaton
    engine, accepted_set = algorithm(parsetree[:case_1], automaton)
    expect(accepted_set.length).to eq 1
    tuple4 = accepted_set.to_a.shift
    dns = engine.backtrack_for(parsetree[:case_1], tuple4)
    expect(dns.map(&:p_)).to eq [1, 5, 8, 11, 14]
    expect(dns.map(&:belongs_to).to_set).to eq Set[0]
  end

  it "works on single automaton - Episode 3" do
    automaton = rcat(
      node(:symbol, "graph"),
      node(:left_curly),
      rrep(rcat(
             node(:symbol),
             node(:equal),
             node(:symbol),
             ror(reps, node(:hash)),
             node(:semi)
           )),
      node(:right_curly)
    ).to_automaton
    engine, accepted_set = algorithm(parsetree[:case_2], automaton)
    expect(accepted_set.length).to eq 1
    tuple4 = accepted_set.to_a.shift
    dns = engine.backtrack_for(parsetree[:case_2], tuple4)
    expect(dns.map(&:p_)).to eq [2, 4, 9, 10, 12, 13, 18,
                                 19, 22, 25, 32, 33]
    expect(dns.map(&:belongs_to).to_set).to eq Set[0]
  end

  it "works on multiple automata - Epsisode 1" do
    automata = [
      node(:args),
      rcat(node(:left), rrep(node(:literal)), node(:right)),
      node(:expr)
    ].map(&:to_automaton)
    engine, accepted_set = algorithm(parsetree[:case_1], *automata)
    expect(accepted_set.length).to eq 2
    automaton_1 = accepted_set.select { |tuple4| tuple4.belongs_to == 1 }
    expect(automaton_1.length).to eq 1
    dns_1 = engine.backtrack_for(parsetree[:case_1], automaton_1.first)
    expect(dns_1.map(&:p_)).to eq [1, 6, 9, 12, 14]
    expect(dns_1.map(&:belongs_to).to_set).to eq Set[1]
    automaton_2 = accepted_set.select { |tuple4| tuple4.belongs_to == 2 }
    expect(automaton_2.length).to eq 1
    dns_2 = engine.backtrack_for(parsetree[:case_1], automaton_2.first)
    expect(dns_2.map(&:p_)).to eq [0]
    expect(dns_2.map(&:belongs_to).to_set).to eq Set[2]
  end

  it "works on multiple automata - Episode 2" do
    automata = [
      rcat(
        node(:symbol, "graph"),
        node(:left_curly),
        rrep(rcat(
               node(:symbol),
               node(:equal),
               node(:symbol),
               ror(reps, node(:hash)),
               node(:semi)
             )),
        node(:right_curly)
      ),
      rcat(node(:symbol), ror(reps, node(:args)), node(:block)),
      node(:call)
    ].map(&:to_automaton)
    engine, accepted_set = algorithm(parsetree[:case_2], *automata)
    expect(accepted_set.length).to eq 3
    automaton_0 = accepted_set.select { |tuple4| tuple4.belongs_to == 0 }
    expect(automaton_0.length).to eq 1
    dns_0 = engine.backtrack_for(parsetree[:case_2], automaton_0.first)
    expect(dns_0.map(&:p_)).to eq [2, 4, 9, 10, 12, 13, 18,
                                   19, 22, 25, 32, 33]
    expect(dns_0.map(&:belongs_to).to_set).to eq Set[0]
    automaton_1 = accepted_set.select { |tuple4| tuple4.belongs_to == 1 }
    expect(automaton_1.length).to eq 1
    dns_1 = engine.backtrack_for(parsetree[:case_2], automaton_1.first)
    expect(dns_1.map(&:p_)).to eq [2, 3]
    expect(dns_1.map(&:belongs_to).to_set).to eq Set[1]
    automaton_2 = accepted_set.select { |tuple4| tuple4.belongs_to == 2 }
    expect(automaton_2.length).to eq 1
    dns_2 = engine.backtrack_for(parsetree[:case_2], automaton_2.first)
    expect(dns_2.map(&:p_)).to eq [1]
    expect(dns_2.map(&:belongs_to).to_set).to eq Set[2]
  end
end
