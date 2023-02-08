require "resyma/parsetree"
require "resyma/language"

def body_ast_of(&block)
  ast, bd, filename, lino = Resyma.source_of(block)
  [Resyma.extract_body(ast), bd, filename, lino]
end

RSpec.describe Resyma::RegexBuildVistor do
  include Resyma::Core::RegexpOp

  def regex_of(&block)
    ast, = body_ast_of(&block)
    Resyma::RegexBuildVistor.new.visit(ast)
  end

  def node(type, value = nil)
    rchr(Resyma::Core::PTNodeMatcher.new(type, value))
  end

  it "can build single matcher by name" do
    regex = regex_of { int }
    expect(regex).to eq node(:int)
  end

  it "can build single matcher by value" do
    regex = regex_of { "(" }
    expect(regex).to eq node(:round_left, "(")
  end

  it "can build single matcher by both type and value" do
    regex = regex_of { int("10") }
    expect(regex).to eq node(:int, "10")
    regex = regex_of { id "graph" }
    expect(regex).to eq node(:id, "graph")
  end

  it "can build a sequence of regex" do
    regex = regex_of { (id("point"); int; int) }
    expect(regex).to eq rcat(node(:id, "point"), node(:int), node(:int))
  end

  it "can build a branches of regex" do
    regex = regex_of { [id("point"), int, int] }
    expect(regex).to eq ror(node(:id, "point"), node(:int), node(:int))
  end

  it "can build a optional regexp" do
    regex = regex_of { [id] }
    expect(regex).to eq ror(reps, node(:id))
  end

  it "can build a *closure" do
    regex = regex_of { id.. }
    expect(regex).to eq rrep(node(:id))
  end

  it "can build a +closure" do
    regex = regex_of { id... }
    expect(regex).to eq rcat(node(:id), rrep(node(:id)))
  end

  it "can build real-world regex" do
    regex = regex_of do
      (id; [(id; (","; id)..)]; block)...
    end
    inner = rcat(
      node(:id),
      ror(reps, rcat(node(:id), rrep(rcat(node(:comma, ","), node(:id))))),
      node(:block)
    )
    expect(regex).to eq rcat(inner, rrep(inner))
  end
end

RSpec.describe Resyma::MonoLanguage do
  it "can build mono-language with single action" do
    ast, bd, filename, lino = body_ast_of do
      (id; [(id; (","; id)..)]; block)... >> [
        nodes, src_binding, src_filename, src_lineno
      ]
    end
    mono = Resyma::MonoLanguage.from(ast, bd, filename, lino)
    expect(mono.automaton).to be_a Resyma::Core::Automaton
    ae = Resyma::ActionEnvironment.new(0, 1, 2, 3)
    expect(mono.action.call(ae)).to eq [0, 1, 2, 3]
  end

  it "can build mono-language with multiple action" do
    state = 0
    ast, bd, filename, lino = body_ast_of do
      alright... >> begin
        state = 1
        nodes
      end
    end
    mono = Resyma::MonoLanguage.from(ast, bd, filename, lino)
    expect(mono.automaton).to be_a Resyma::Core::Automaton
    ae = Resyma::ActionEnvironment.new(0, 1, 2, 3)
    expect(mono.action.call(ae)).to eq 0
    expect(state).to eq 1
  end

  it "can shadow special variables" do
    nodes, src_binding, src_filename, = %w[a b c d]
    ast, bd, filename, lino = body_ast_of do
      wait.. >> [nodes, src_binding, src_filename, src_lineno]
    end
    mono = Resyma::MonoLanguage.from(ast, bd, filename, lino)
    expect(mono.automaton).to be_a Resyma::Core::Automaton
    ae = Resyma::ActionEnvironment.new(0, 1, 2, 3)
    expect(mono.action.call(ae)).to eq ["a", "b", "c", 3]
  end
end

class ManyNihil < Resyma::Language
  def syntax
    the_nil... >> "#{nodes.length} nil"
  end
end

class ManyNumber < Resyma::Language
  def syntax
    int... >> "#{nodes.length} int"
    float... >> "#{nodes.length} float"
  end
end

RSpec.describe Resyma::Language do
  it "raises error if Resyma::Language is used" do
    expect do
      Resyma::Language.load { hello! }
    end.to raise_error Resyma::LanguageSyntaxError
  end

  it "works with single mono-language" do
    expect(ManyNihil.load { nil; nil }).to eq "2 nil"
  end

  it "works with multiple mono-languages" do
    expect(ManyNumber.load { 1; 2; 3; 4; 5 }).to eq "5 int"
    expect(ManyNumber.load { 1.0; 2.0 }).to eq "2 float"
  end
end
