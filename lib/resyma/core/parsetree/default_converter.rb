require "resyma/core/parsetree/definition"
require "resyma/core/parsetree/converter"

module Resyma
  module Core
    DEFAULT_CONVERTER = Converter.new
  end
end

Resyma::Core::DEFAULT_CONVERTER.instance_eval do
  def make_token(type, value, parent, index, ast)
    Resyma::Core::ParseTree.new(type, [value], parent, index, true, ast)
  end

  SIMPLE_LITERAL = %i[
    true
    false
    nil
    complex
    rational
  ]

  def_rule SIMPLE_LITERAL do |ast, parent, index|
    make_token ast.type, ast.loc.expression.source, parent, index, ast
  end

  NUMBER_REGEX = /^\s*(\+|-)?\s*([0-9.]+)\s*$/
  def_rule %i[int float] do |ast, parent, index|
    m = NUMBER_REGEX.match(ast.loc.expression.source)
    if m.nil?
      raise Resyma::Core::ConversionError,
            "Internal error: Number pattern [#{ast.loc.expression}] is invalid"
    end
    Resyma::Core::ParseTreeBuilder.root(ast.type, nil, index, ast) do
      leaf :numop, m[1] unless m[1].nil?
      leaf :numbase, m[2]
    end.build(parent)
  end

  TOKEN_VALUE_TABLE = {
    "(" => :round_left,
    ")" => :round_right,
    "begin" => :kwd_begin,
    "end" => :kwd_end
  }

  def check_boundary(boundary, pt_builder)
    return if boundary.nil?

    value = boundary.source
    type = TOKEN_VALUE_TABLE[value]
    if type.nil?
      raise Resyma::Core::ConversionError,
            "Unknwon boundary-token of AST with type <begin>: #{value}"
    end
    pt_builder.add_child!(type, nil, true, [value])
  end

  def_rule %i[begin kwbegin] do |ast, parent, index|
    ptb = Resyma::Core::ParseTreeBuilder.new(:begin, index, false, [], ast)
    check_boundary ast.loc.begin, ptb
    ast.children.each do |sub|
      ptb.add_parsetree_child!(convert(sub), sub)
    end
    check_boundary ast.loc.end, ptb
    ptb.build(parent)
  end
end
