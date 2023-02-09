require "resyma/core/parsetree"
require "unparser"

module Resyma
  class UnsupportedError < Error; end
  class NoASTError < Error; end

  #
  # Derive an AST from a procedure-like object
  #
  # @param [#to_proc] procedure Typically Proc or Method
  #
  # @return [[Parser::AST::Node, Binding, filename, lino]] An abstract syntax
  #   tree, the environment surrounding the procedure, and its source location
  #
  def self.source_of(procedure)
    procedure = procedure.to_proc
    ast = Core.locate(procedure)
    raise UnsupportedError, "Cannot locate the source of #{ast}" if ast.nil?

    [ast, procedure.binding, *procedure.source_location]
  end

  #
  # Extract body part from AST of a procedure-like object
  #
  # @param [Parser::AST::Node] procedure_ast AST of a Proc or a Method
  #
  # @return [Parser::AST::Node] AST of function body
  #
  def self.extract_body(procedure_ast)
    case procedure_ast.type
    when :block then procedure_ast.children[2]
    when :def then procedure_ast.children[2]
    when :defs then procedure_ast.children[3]
    else
      raise UnsupportedError,
            "Not a supported type of procedure: #{procedure_ast.type}"
    end
  end

  #
  # Derive the parse tree of a function body
  #
  # @param [#to_proc] procedure A procedure-like object, typically Proc and
  #   Method
  #
  # @return [[Resyma::Core::ParseTree, Binding, filename, lino]] A parse tree,
  #   the environment surrounding the procedure, and its source location
  #
  def self.body_parsetree_of(procedure)
    ast, bd, filename, lino = source_of(procedure)
    body_ast = extract_body(ast)
    [Core::DEFAULT_CONVERTER.convert(body_ast), bd, filename, lino]
  end

  #
  # Evaluator for Resyma::Core::ParseTree
  #
  class Evaluator
    def initialize
      @rules = {}
    end

    #
    # Define a evaluation rule
    #
    # @param [Symbol, Array<Symbol>] type Type(s) assocating to the rule
    # @yieldparam [Parser::AST::Node] AST of the node
    # @yieldparam [Binding] The environment surrounding the DSL
    # @yieldparam [String] filename Source location
    # @yieldparam [Integer] lino Source location
    #
    # @return [nil] Nothing
    #
    def def_rule(type, &block)
      types = type.is_a?(Array) ? type : [type]
      types.each { |sym| @rules[sym] = block }
      nil
    end

    #
    # Evaluate AST of the parse tree
    #
    # @param [Resyma::Core::ParseTree] parsetree A parse tree whose `ast` is not
    #   `nil`
    # @param [Binding] bd Environment
    # @param [String] filename Source location
    # @param [Integer] lino Source location
    #
    # @return [Object] Reterning value of corresponding evaluating rule
    #
    def evaluate(parsetree, bd, filename, lino)
      if parsetree.ast.nil?
        raise NoASTError,
              "AST of parse trees is necessary for evaluation"
      end

      evaluate_ast(parsetree.ast, bd, filename, lino)
    end

    #
    # Evaluate the AST by defined rules
    #
    # @param [Parser::AST::Node] ast An abstract syntax tree
    # @param [Binding] bd Environment
    # @param [String] filename Source location
    # @param [Integer] lino Source location
    #
    # @return [Object] Returning value of corresponding evaluating rule
    #
    def evaluate_ast(ast, bd, filename, lino)
      evaluator = @rules[ast.type]
      if evaluator.nil?
        fallback ast, bd, filename, lino
      else
        evaluator.call(ast, bd, filename, lino)
      end
    end

    #
    # Fallback evaluating method. AST whose type is not defined by current
    #   evaluator will be passed to this method. The default action is unparse
    #   the AST by `unparser` and evaluate the string by `eval`
    #
    # @param [Parser::AST::Node] ast An abstract syntax tree
    # @param [Binding] bd The environment
    # @param [String] filename Source location
    # @param [Integer] lino Source location
    #
    # @return [Object] Evaluating result
    #
    def fallback(ast, bd, filename, lino)
      string = Unparser.unparse(ast)
      eval(string, bd, filename, lino)
    end
  end

  module Core
    class ParseTree
      #
      # Evaluate current parse tree using default evaluator
      #
      # @param [Binding] bd Environment
      # @param [String] filename Source location
      # @param [Integer] lino Source location
      #
      # @return [Object] Evaluation result
      #
      def to_ruby(bd = binding, filename = "(resyma)", lino = 1)
        Evaluator.new.evaluate(self, bd, filename, lino)
      end
    end
  end
end
