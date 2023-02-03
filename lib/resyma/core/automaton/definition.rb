require "set"

module Resyma
  module Core
    class Automaton
      #
      # Returns a new instance of Resyma::Core::Automaton
      #
      # @param [Resyma::Core::State] start Starting state of the automaton
      # @param [Set<Resyma::Core::State>] accept_set A set of states accepted by
      #   the automaton
      # @param [Resyma::Core::TransitionTable] transition_table Transitions of
      #   the automaton
      #
      def initialize(start, accept_set, transition_table = TransitionTable.new)
        @start = start
        @accept_set = accept_set
        @transition_table = transition_table
      end

      attr_reader :start, :accept_set, :transition_table

      def accept?(state)
        @accept_set.include? state
      end

      def destination(state, value)
        @transition_table.destination(state, value)
      end
    end
  end
end
