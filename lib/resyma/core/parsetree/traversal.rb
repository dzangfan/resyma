require "resyma/core/parsetree/definition"

module Resyma
  module Core
    class ParseTree
      def depth_first_each(&block)
        yield self

        return if leaf?

        @children.each do |child|
          child.depth_first_each(&block)
        end
      end
    end
  end
end
