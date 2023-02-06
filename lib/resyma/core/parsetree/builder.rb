require "resyma/core/parsetree/definition"

module Resyma
  module Core
    def ParseTree.build(parent = nil)
      @parent = parent
      self
    end

    #
    # Builder of Resyma::Core::ParseTree
    #
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
      # Define and add a node to current tree as a child
      #
      # @param [Symbol] symbol Type of the node
      # @param [Parser::AST::Node] ast Abstract syntax tree of the new node
      # @param [true, false] is_leaf Is a leaf node?
      # @param [Array] value Should only be used when `is_leaf`, meaning that
      #   this node is a token node. Pass an array with a single value as the
      #   value of the token
      #
      # @return [Resyma::Core::ParseTreeBuilder] The builder of the new node
      #
      def add_child!(symbol, ast = nil, is_leaf = false, value = [])
        ptb = ParseTreeBuilder.new(symbol, @children.length, is_leaf, value,
                                   ast)
        @children.push ptb
        ptb
      end

      #
      # Add a node to current tree as a child
      #
      # @param [Resyma::Core::ParseTree] tree The new child
      #
      # @return [nil] Nothing
      #
      def add_parsetree_child!(tree, ast = nil)
        tree.index = @children.length
        tree.ast = ast
        @children.push tree
        nil
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
