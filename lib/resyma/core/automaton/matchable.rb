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

      #
      # Matches with another Resyma::Core::Matchable
      #
      # @param [Resyma::Core::Matchable] _another Another matchable object
      #
      # @return [true,false] Result
      #
      def identity_with_matchable?(_another)
        false
      end
    end
  end
end
