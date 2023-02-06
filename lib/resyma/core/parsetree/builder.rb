module Resyma
  module Core
    class ParseTreeBuilder
      def initialize(symbol, index = 0, is_leaf = false,
                     children = [])
        @symbol = symbol
        @children = children
        @index = index
        @is_leaf = is_leaf
      end

      #
      # Define a child node and return the new AST
      #
      # @param [Symbol] symbol Symbol of the child
      #
      # @return [Resyma::Core::ParseTreeBuilder] Builder of the new child
      #
      def add_child!(symbol, is_leaf = false, value = [])
        ptb = ParseTreeBuilder.new(symbol, @children.length, is_leaf, value)
        @children.push ptb
        ptb
      end

      def build(parent = nil)
        pt = ParseTree.new(@symbol, nil, parent, @index, @is_leaf)
        pt.children = if @is_leaf
                        @children
                      else
                        @children.map { |c| c.build(pt) }
                      end
        pt
      end

      def node(symbol, &block)
        ptb = add_child! symbol
        ptb.instance_eval(&block) unless block.nil?
        ptb
      end

      def leaf(symbol, value)
        add_child! symbol, true, [value]
      end

      def self.root(symbol, value = nil, &block)
        if block.nil?
          ParseTreeBuilder.new(symbol, 0, true, [value])
        else
          ptb = ParseTreeBuilder.new(symbol)
          ptb.instance_eval(&block) unless block.nil?
          ptb
        end
      end
    end
  end
end
