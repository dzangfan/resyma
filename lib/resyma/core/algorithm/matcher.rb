require "resyma/core/automaton/matchable"

module Resyma
  module Core
    class PTNodeMatcher
      include Matchable
      #
      # Create a instance of parse tree node matcher
      #
      # @param [Symbol] type Symbol of the node
      # @param [Object] value Value of the node, indicating that the node is a
      #   token. Currently, `nil` means that the node is an non-leaf node or it
      #   is a leaf node but its value is unimportant
      #
      def initialize(type, value = nil)
        @type = type
        @value = value
      end

      attr_reader :type, :value

      def ==(other)
        other.is_a?(PTNodeMatcher) &&
          other.type == @type &&
          other.value == @value
      end

      #
      # Whether the matcher matches with the parse tree
      #
      # @param [Resyma::Core::ParseTree] parsetree Node of parse tree
      #
      # @return [true, false] Result
      #
      def match_with_value?(parsetree)
        if parsetree.is_a?(Resyma::Core::ParseTree)
          parsetree.symbol == @type &&
            (@value.nil? || (parsetree.leaf? &&
                             parsetree.children[0] == @value))
        elsif parsetree.is_a?(PTNodeMatcher)
          self == parsetree
        else
          false
        end
      end
    end
  end
end
