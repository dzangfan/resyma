require "set"

module Resyma
  module Core
    Field = Struct.new("Field", :id, :start, :trans)

    def Field.make_clean_field
      Field.new(-1, Set[], Set[])
    end

    #
    # Parse tree with fields used by the matching algorithm
    #
    class ParseTree
      attr_accessor :symbol, :children, :parent, :index, :field, :ast

      def initialize(symbol, children, parent, index, is_leaf)
        @symbol = symbol
        @children = children
        @parent = parent
        @index = index
        @field = Field.make_clean_field
        @is_leaf = is_leaf
        @ast = nil
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
