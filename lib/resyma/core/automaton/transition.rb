module Resyma
  module Core
    class TransitionTable

      attr_reader :table

      Candidate = Struct.new("Candidate", :condition, :destination)

      def initialize
        @table = Hash.new { |hash, key| hash[key] = [] }
      end

      #
      # Add a transition from `from_state` to `to_state` through `matchable`
      #
      # @param [Resyma::Core::State] from_state Starting state
      # @param [Resyma::Core::Matchable] matchable Condition of transition
      # @param [Resyma::Core::State] to_state Destination state
      #
      # @return [nil] Undefined
      #
      def add_transition!(from_state, matchable, to_state)
        @table[from_state].push Candidate.new(matchable, to_state)
        nil
      end

      #
      # Query the destination state in the table. `nil` will be returned if the
      # destination is not defined
      #
      # @param [Resyma::Core::State] from_state Starting state
      # @param [Object] value Value to be matched, see `Resyme::Core::Matchable`
      #
      # @return [nil, Resyma::Core::State] The destination if exists
      #
      def destination(from_state, value)
        @table[from_state].each do |candidate|
          if candidate.condition.match_with_value? value
            return candidate.destination
          end
        end
        nil
      end

      #
      # Candidate states that has a transition starting from `from_state`
      #
      # @param [Resyma::Core::State] from_state Starting state
      #
      # @return [Array<Resyma::Core::TransitionTable::Candidate>] A list of
      #   candidates
      #
      def candidates(from_state)
        @table[from_state]
      end
    end
  end
end
