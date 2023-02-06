require "resyma/core/parsetree/definition"

module Resyma
  module Core
    class ParseTree
      #
      # Depth-firstly traverse the tree
      #
      # @yieldparam [Resyma::Core::ParseTree] A parse tree
      #
      # @return [nil] Nothing
      #
      def depth_first_each(&block)
        yield self

        return if leaf?

        @children.each do |child|
          child.depth_first_each(&block)
        end

        nil
      end
    end
  end
end
