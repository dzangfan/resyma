require "set"

module Resyma
  module Core
    class Field
      #
      # Create an instance of Field, which is set and used by the matching
      #   algorithm
      #
      # @param [Integer] id ID of the node
      # @param [Hash<Integer, Set<Resyma::Core::Tuple2>>] start Sets of 2
      #   tuples, corresponding to different automata
      # @param [Hash<Integer, Set<Resyma::Core::Tuple4>>] trans Sets of 4
      #   tuples, corresponding to different automata
      #
      def initialize(id, start, trans)
        @id = id
        @start = start
        @trans = trans
      end

      attr_accessor :id, :start, :trans

      def self.clean_field
        start = Hash.new { |hash, key| hash[key] = Set[] }
        trans = Hash.new { |hash, key| hash[key] = Set[] }
        new(-1, start, trans)
      end
    end

    #
    # Parse tree with fields used by the matching algorithm
    #
    class ParseTree
      attr_accessor :symbol, :children, :parent, :index, :field, :ast, :cache

      #
      # Create an instance of parse tree
      #
      # @param [Symbol] symbol Symbol associating to the node
      # @param [Array] children Subtrees of current node, or an array with a
      #   single element if it is a leaf
      # @param [Resyma::Core::ParseTree, nil] parent Parent tree, or nil if the
      #   current node is the root
      # @param [Integer] index There are `index` brother preceding to the
      #   current node
      # @param [true,false] is_leaf Whether or not the current node is a leaf
      # @param [Parser::AST::Node,nil] ast Its corresponding abstract syntax
      #   tree
      #
      def initialize(symbol, children, parent, index, is_leaf, ast = nil)
        @symbol = symbol
        @children = children
        @parent = parent
        @index = index
        @field = Field.clean_field
        @is_leaf = is_leaf
        @ast = ast
        @cache = {}
      end

      def root?
        @parent.nil?
      end

      def leaf?
        @is_leaf
      end
    end
  end
end
