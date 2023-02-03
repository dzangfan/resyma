module Resyma
  module Core
    class State
      def initialize(id)
        @id = id
      end

      attr_reader :id

      #
      # Returns a new State whose ID is `id`
      #
      # @param [Integer] id ID of the state
      #
      # @return [Resyma::Core::State] A new instance of State
      #
      def self.with_id(id)
        new(id)
      end
    end
  end
end
