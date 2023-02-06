module Resyma
  module Core
    module Matchable
      #
      # Matches with an object
      #
      # @param [Object] _other Value to be matched
      #
      # @return [true,false] Result
      #
      def match_with_value?(_other)
        false
      end
    end
  end
end
