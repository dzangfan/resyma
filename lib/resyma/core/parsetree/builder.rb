module Resyma
  module Core
    class ParseTreeBuilder
      def initialize(symbol, index = 0, is_leaf = false,
                     children = [], ast = nil)
        @symbol = symbol
        @children = children
        @index = index
        @is_leaf = is_leaf
        @ast = ast
      end

      #
      # Define a child node and return the new AST
      #
      # @param [Symbol] symbol Symbol of the child
      #
      # @return [Resyma::Core::ParseTreeBuilder] Builder of the new child
      #
      def add_child!(symbol, ast = nil, is_leaf = false, value = [])
        ptb = ParseTreeBuilder.new(symbol, @children.length, is_leaf, value,
                                   ast)
        @children.push ptb
        ptb
      end

      def build(parent = nil)
        pt = ParseTree.new(@symbol, nil, parent, @index, @is_leaf, @ast)
        pt.children = if @is_leaf
                        @children
                      else
                        @children.map { |c| c.build(pt) }
                      end
        pt
      end

      def node(symbol, ast = nil, &block)
        ptb = add_child! symbol, ast
        ptb.instance_eval(&block) unless block.nil?
        ptb
      end

      def leaf(symbol, value, ast = nil)
        add_child! symbol, ast, true, [value]
      end

      def self.root(symbol, value = nil, index = 0, ast = nil, &block)
        if block.nil?
          ParseTreeBuilder.new(symbol, index, true, [value], ast)
        else
          ptb = ParseTreeBuilder.new(symbol, index, is_leaf = false,
                                     children = [], ast = ast)
          ptb.instance_eval(&block) unless block.nil?
          ptb
        end
      end
    end
  end
end
