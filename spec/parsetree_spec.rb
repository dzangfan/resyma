require "parser"
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
    ast = Resyma::Core.locate(method :block_of)
    expect(ast).to be_a Parser::AST::Node
    expect(ast.type).to be :def
  end
end