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
      attr_accessor :symbol, :children, :parent, :index, :field, :ast

      def initialize(symbol, children, parent, index, is_leaf, ast = nil)
        @symbol = symbol
        @children = children
        @parent = parent
        @index = index
        @field = Field.clean_field
        @is_leaf = is_leaf
        @ast = ast
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
