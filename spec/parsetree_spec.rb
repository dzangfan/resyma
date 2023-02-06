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
    expect(node.field.id).to eq(-1)
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

RSpec.describe Resyma::Core::ParseTree do
  it "can be traversed depth-firstly" do
    t = Resyma::Core::ParseTreeBuilder.root(0) do
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
    order = []
    t.depth_first_each do |tree|
      order.push tree.symbol
    end
    expect(order).to eq (0..11).to_a
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

RSpec.describe Resyma::Core::DEFAULT_CONVERTER do
  def check_literal(str, type, value)
    ast = Parser::CurrentRuby.parse(str)
    pt = Resyma::Core::DEFAULT_CONVERTER.convert(ast)
    expect(pt.symbol).to be type
    expect(pt.children).to eq [value]
    expect(pt.ast).to be_a Parser::AST::Node
    expect(pt.field.id).to eq(-1)
    expect(pt.index).to eq 0
    expect(pt.parent).to be_nil
  end

  it "can convert literals" do
    check_literal("true", :true, "true")
    check_literal("false", :false, "false")
    check_literal("nil", :nil, "nil")
    check_literal("1i", :complex, "1i")
  end

  def check_numeric(str, type, numop, numbase)
    ast = Parser::CurrentRuby.parse(str)
    pt = Resyma::Core::DEFAULT_CONVERTER.convert(ast)
    expect(pt.ast).to be_a Parser::AST::Node
    expect(pt.field.id).to eq(-1)
    expect(pt.index).to eq 0
    expect(pt.parent).to be_nil
    expect(pt.symbol).to be type
    baseidx = if numop.nil?
                expect(pt.children.size).to eq 1
                0
              else
                expect(pt.children.size).to eq 2
                oppt = pt.children[0]
                expect(oppt.index).to eq 0
                expect(oppt.parent).to be pt
                expect(oppt.symbol).to be :numop
                expect(oppt.children).to eq [numop]
                1
              end
    basept = pt.children[baseidx]
    expect(basept.index).to eq baseidx
    expect(basept.parent).to be pt
    expect(basept.symbol).to be :numbase
    expect(basept.children).to eq [numbase]
  end

  it "can convert numerics" do
    check_numeric("1", :int, nil, "1")
    check_numeric("3.1", :float, nil, "3.1")
    check_numeric("-10", :int, "-", "10")
    check_numeric("  + 200", :int, "+", "200")
    check_numeric("-0.0", :float, "-", "0.0")
    check_numeric("+ 10.2", :float, "+", "10.2")
  end

  def quick_check(pt, type, value: nil, parent: nil, index: nil, is_leaf: nil)
    expect(pt.symbol).to be type
    expect(pt.children).to eq [value] unless value.nil?
    expect(pt.parent).to be parent unless parent.nil?
    expect(pt.index).to eq index unless index.nil?
    expect(pt.leaf?).to eq is_leaf unless is_leaf.nil?
  end

  def check_begin_boundary(boundary, pt)
    begin_token_table = {
      round_left: "(",
      round_right: ")",
      kwd_begin: "begin",
      kwd_end: "end"
    }
    type = boundary
    value = begin_token_table[boundary]
    quick_check(pt, type, value: value)
  end

  def check_begin(str, size, left, right)
    ast = Parser::CurrentRuby.parse(str)
    pt = Resyma::Core::DEFAULT_CONVERTER.convert(ast)
    expect(pt.ast).to be_a Parser::AST::Node
    expect(pt.field.id).to eq(-1)
    expect(pt.symbol).to be :begin
    expect(pt.children.size).to eq size
    check_begin_boundary left, pt.children.first unless left.nil?
    check_begin_boundary right, pt.children.last unless right.nil?
    pt
  end

  it "can convert begin-statements" do
    check_begin("()", 2, :round_left, :round_right)
    pt = check_begin("(1)", 3, :round_left, :round_right)
    quick_check pt.children[1], :int, index: 1
    pt = check_begin <<-EOF, 5, :kwd_begin, :kwd_end
      begin
        nil
        false; 0.0
      end
    EOF
    quick_check pt.children[1], :nil, is_leaf: true, value: "nil", index: 1
    quick_check pt.children[2], :false, is_leaf: true, value: "false", index: 2
    quick_check pt.children[3], :float, index: 3
  end
end
