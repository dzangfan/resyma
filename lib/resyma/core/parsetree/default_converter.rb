require "resyma/core/parsetree/definition"
require "resyma/core/parsetree/converter"

module Resyma
  module Core
    DEFAULT_CONVERTER = Converter.new

    CONST_TOKEN_TABLE = {
      "(" => :round_left,
      ")" => :round_right,
      "begin" => :kwd_begin,
      "end" => :kwd_end,
      "," => :comma,
      "[" => :square_left,
      "]" => :square_right,
      "*" => :star,
      "**" => :star2,
      ":" => :colon,
      "=>" => :arrow,
      "{" => :curly_left,
      "}" => :curly_right,
      ".." => :dot2,
      "..." => :dot3,
      "defined?" => :defined?,
      "." => :dot,
      "&." => :and_dot
    }.freeze
  end
end

Resyma::Core::DEFAULT_CONVERTER.instance_eval do
  ctt = Resyma::Core::CONST_TOKEN_TABLE

  def make_token(type, value, parent, index, ast)
    Resyma::Core::ParseTree.new(type, [value], parent, index, true, ast)
  end

  simple_literal = {
    true: :the_true,
    false: :the_false,
    nil: :the_nil,
    complex: :complex,
    rational: :rational,
    str: :str,
    regexp: :regexp,
    sym: :sym,
    self: :the_self,
    lvar: :id,
    ivar: :ivar,
    cvar: :cvar,
    gvar: :gvar,
    nth_ref: :nth_ref,
    back_ref: :back_ref
  }

  def_rule simple_literal.keys do |ast, parent, index|
    make_token simple_literal[ast.type], ast.loc.expression.source,
               parent, index, ast
  end

  number_regexp = /^\s*(\+|-)?\s*([0-9.]+)\s*$/
  def_rule %i[int float] do |ast, parent, index|
    m = number_regexp.match(ast.loc.expression.source)
    if m.nil?
      raise Resyma::Core::ConversionError,
            "Internal error: Number pattern [#{ast.loc.expression}] is invalid"
    end
    Resyma::Core::ParseTreeBuilder.root(ast.type, nil, index, ast) do
      leaf :numop, m[1] unless m[1].nil?
      leaf :numbase, m[2]
    end.build(parent)
  end

  def check_boundary(boundary, pt_builder)
    return if boundary.nil?

    value = boundary.source
    type = ctt[value]
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

  def_rule %i[dstr dsym xstr] do |ast, parent, index|
    ptb = Resyma::Core::ParseTreeBuilder.new(ast.type, index, false, [], ast)
    ast.children.each do |sub|
      ptb.add_parsetree_child!(convert(sub), sub)
    end
    ptb.build(parent)
  end

  def def_rule_for_seq(type, open, sep, close)
    def_rule type do |ast, parent, index|
      ptb = Resyma::Core::ParseTreeBuilder.new(ast.type, index, false, [], ast)
      ptb.add_child!(ctt[open], nil, true, [open]) unless open.nil?
      unless ast.children.empty?
        first = ast.children.first
        ptb.add_parsetree_child!(convert(first), first)
        ast.children[1..].each do |sub|
          ptb.add_child!(ctt[sep], nil, true, [sep]) unless sep.nil?
          ptb.add_parsetree_child!(convert(sub), sub)
        end
      end
      ptb.add_child!(ctt[close], nil, true, [close]) unless close.nil?
      ptb.build(parent)
    end
  end

  def_rule_for_seq(:array, "[", ",", "]")
  def_rule_for_seq(:hash, "{", ",", "}")
  def_rule_for_seq(:kwargs, nil, ",", nil)

  def_rule %i[splat kwsplat] do |ast, parent, index|
    star = ast.loc.operator.source
    ptb = Resyma::Core::ParseTreeBuilder.new(ast.type, index, false, [], ast)
    ptb.add_child!(ctt[star], nil, true, [star])
    first = ast.children.first
    ptb.add_parsetree_child!(convert(first), first)
    ptb.build(parent)
  end

  def_rule :pair do |ast, parent, index|
    left, right = ast.children
    op_value = ast.loc.operator.source
    op_type = ctt[op_value]
    if op_type.nil?
      raise Resyma::Core::ConversionError,
            "Unknown operator for hash pair: #{op_value}"
    end
    ptb = Resyma::Core::ParseTreeBuilder.new(ast.type, index, false, [], ast)
    ptb.add_parsetree_child!(convert(left), left)
    ptb.add_child!(op_type, nil, true, [op_value])
    ptb.add_parsetree_child!(convert(right), right)
    ptb.build(parent)
  end

  def_rule %i[erange irange] do |ast, parent, index|
    ptb = Resyma::Core::ParseTreeBuilder.new(ast.type, index, false, [], ast)
    left, right = ast.children
    op_value = ast.loc.operator.source
    ptb.add_parsetree_child!(convert(left), left) unless left.nil?
    ptb.add_child!(ctt[op_value], nil, true, [op_value])
    ptb.add_parsetree_child!(convert(right), right) unless right.nil?
    ptb.build(parent)
  end

  def_rule :const do |ast, parent, index|
    scope, sym = ast.children
    maybe_colon = ast.loc.double_colon
    ptb = Resyma::Core::ParseTreeBuilder.new(:const, index, false, [], ast)
    unless scope.nil? || scope.type == :cbase
      ptb.add_parsetree_child!(convert(scope), scope)
    end
    unless maybe_colon.nil?
      op_value = maybe_colon.source
      ptb.add_child!(ctt[op_value], nil, true, [op_value])
    end
    ptb.add_child!(:id, nil, true, [sym])
    ptb.build(parent)
  end

  def try_token!(ptb, optional_range)
    ctt = Resyma::Core::CONST_TOKEN_TABLE
    return if optional_range.nil?

    token_value = if optional_range.is_a?(String)
                    optional_range
                  else
                    optional_range.source
                  end
    ptb.add_child!(ctt[token_value], nil, true, [token_value])
  end

  def_rule :defined? do |ast, parent, index|
    ptb = Resyma::Core::ParseTreeBuilder.new(:defined?, index, false, [], ast)
    try_token! ptb, ast.loc.source.keyword
    try_token! ptb, ast.loc.source.begin
    expr, = ast.children
    ptb.add_parsetree_child!(convert(expr), expr)
    try_token! ptb, ast.loc.source.end
    ptb.build(parent)
  end

  asgn_table = {
    lvasgn: :id,
    ivasgn: :ivar,
    cvasgn: :cvar,
    gvasgn: :gvar
  }

  def_rule %i[lvasgn ivasgn cvasgn gvasgn] do |ast, parent, index|
    name = ast.loc.name.source
    value = ast.children[1]
    ptb = Resyma::Core::ParseTreeBuilder.new(ast.type, index, false, [], ast)
    name_tkn = make_token(asgn_table[ast.type], name, nil, 0, nil)
    ptb.add_parsetree_child!(name_tkn)
    try_token!(ptb, ast.loc.operator)
    ptb.add_parsetree_child!(convert(value), value)
    ptb.build(parent)
  end

  #
  # @yieldparam [Resyma::Core::ParseTreeBuilder]
  #
  def with_ptb(ast, parent, index, type = ast.type)
    ptb = Resyma::Core::ParseTreeBuilder.new(type, index, false, [], ast)
    yield ptb
    ptb.build(parent)
  end

  def add_ast!(ptb, ast)
    ptb.add_parsetree_child!(convert(ast), ast)
  end

  def_rule :casgn do |ast, parent, index|
    with_ptb ast, parent, index do |ptb|
      base, sym, value_ast = ast.children
      add_ast! ptb, base unless base.nil? || base.type == :cbase
      try_token! ptb, ast.loc.double_colon
      name = ast.loc.name.source
      name_tkn = make_token(:id, name, nil, 0, nil)
      ptb.add_parsetree_child!(name_tkn)
      try_token! ptb, ast.loc.operator
      add_ast! ptb, value_ast
    end
  end

  def add_id!(ptb, name)
    tkn = make_token(:id, name.to_s, nil, 0, nil)
    ptb.add_parsetree_child!(tkn)
  end

  def_rule %i[send csend] do |ast, parent, index|
    with_ptb ast, parent, index do |ptb|
      if ast.loc.respond_to? :operator
        rec, _, rhs = ast.children
        add_ast! ptb, rec
        try_token! ptb, ast.loc.dot
        selector = ast.loc.selector.source
        add_id! ptb, selector
        try_token! ptb, ast.loc.operator
        add_ast! ptb, rhs
      end
    end
  end
end
