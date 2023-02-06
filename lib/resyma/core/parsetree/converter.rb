require "parser"

module Resyma
  module Core
    class ConversionError < Resyma::Error; end

    #
    # Converter for Parser::AST::Node
    #
    class Converter
      def initialize
        @rules = {}
        @fallback = nil
      end

      #
      # Define the conversion rule for AST with particular type(s)
      #
      # @param [Symbol, Array<Symbol>] type_or_types Types
      # @param [Proc] &cvt Procedure taking a AST and returning a parse tree,
      #  i.e. Parser::AST::Node -> Resyma::Core::ParseTree
      #
      # @return [nil] Nothing
      #
      def def_rule(type_or_types, &cvt)
        types = if type_or_types.is_a?(Symbol)
                  [type_or_types]
                else
                  type_or_types
                end
        types.each { |type| @rules[type] = cvt }
      end

      def def_fallback(&cvt)
        @fallback = cvt
      end

      #
      # Convert a Parser::AST::Node to Resyma::Core::ParseTree
      #
      # @param [Parser::AST::Node] ast An abstract syntax tree
      #
      # @return [Resyma::Core::ParseTree] A concrete syntax tree
      #
      def convert(ast, parent = nil, index = 0)
        converter = @rules[ast.type]
        if !converter.nil?
          converter.call(ast, parent, index)
        elsif !@fallback.nil?
          @fallback.call(ast, parent, index)
        else
          raise Resyma::Core::ConversionError,
                "Unable to convert AST whose type is #{ast.type}"
        end
      end
    end
  end
end
