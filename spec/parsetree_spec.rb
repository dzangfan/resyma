require "parser"
require "parser/current"
require "resyma/core/parsetree"

RSpec.describe Resyma::Core::SourceLocator do
  def block_of(*_, &block)
    block
  end

  it "can locate AST of blocks" do
    ast = Resyma::Core.locate(block_of do
      something...
    end)
    expect(ast).to be_a Parser::AST::Node
    expect(ast.type).to be :block
  end

  it "can locate AST of methods" do
    ast = Resyma::Core.locate(method(:block_of))
    expect(ast).to be_a Parser::AST::Node
    expect(ast.type).to be :def
  end
end

RSpec.describe Resyma::Core::ParseTreeBuilder do
  def check(node, symbol, children_amount, index, parent, is_leaf)
    expect(node).to be_a Resyma::Core::ParseTree
    expect(node.field).to eq Resyma::Core::Field.make_clean_field
    expect(node.children.length).to eq children_amount
    expect(node.index).to eq index
    expect(node.parent).to be parent
    expect(node.symbol).to be symbol
    expect(node.leaf?).to be is_leaf
  end

  it "can build a tree with single node" do
    t = Resyma::Core::ParseTreeBuilder.root(:foo).build
    check(t, :foo, 1, 0, nil, true)
  end

  it "can build a tree with multiple children" do
    t = Resyma::Core::ParseTreeBuilder.root(:binary) do
      node :left do
        leaf(:number, 10)
      end
      leaf(:plus, "+")
      node :right do
        leaf(:number, 15)
      end
    end.build
    check(t, :binary, 3, 0, nil, false)
    check(t.children[0], :left, 1, 0, t, false)
    check(t.children[0].children[0], :number, 1, 0, t.children[0], true)
    expect(t.children[0].children[0].children).to eq [10]
    check(t.children[1], :plus, 1, 1, t, true)
    expect(t.children[1].children).to eq ["+"]
    check(t.children[2], :right, 1, 2, t, false)
    check(t.children[2].children[0], :number, 1, 0, t.children[2], true)
    expect(t.children[2].children[0].children).to eq [15]
  end
end

RSpec.describe Resyma::Core::Converter do
  cvt = Resyma::Core::Converter.new
  cvt.def_rule(:block) { 0 }
  cvt.def_rule(:int) { 1 }
  cvt.def_fallback { 2 }

  it "can handle defined rules" do
    ast = Parser::CurrentRuby.parse("proc {}")
    expect(cvt.convert(ast)).to eq 0
    ast = Parser::CurrentRuby.parse("1")
    expect(cvt.convert(ast)).to eq 1
  end

  it "can handle undefined rules by the fallback rule" do
    ast = Parser::CurrentRuby.parse(":unk")
    expect(cvt.convert(ast)).to be 2
  end
end
