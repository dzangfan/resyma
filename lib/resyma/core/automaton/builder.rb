require "set"

require "resyma/core/automaton/state"
require "resyma/core/automaton/transition"

module Resyma
  module Core
    class AutomatonBuilder
      class NoStartError < Resyma::Error; end

      def initialize
        @next_id = 0
        @start = nil
        @accept_set = Set[]
        @transition_table = TransitionTable.new
      end

      #
      # Adds a new state to the automaton and returns it
      #
      # @return [Resyma::Core::State] A new state
      #
      def new_state!(start: false, accept: false)
        inst = State.with_id(@next_id)
        @next_id += 1
        start! inst if start
        accept! inst if accept
        inst
      end

      #
      # Adds a new transition to the automaton
      #
      # @param [Resyma::Core::State] from_state Starting state
      # @param [Resyma::Core::Matchable] matchable Condition
      # @param [Resyma::Core::State] to_state Destination
      #
      # @return [nil] Nothing
      #
      def add_transition!(from_state, matchable, to_state)
        @transition_table.add_transition!(from_state, matchable, to_state)
      end

      #
      # Specify a starting state for the automaton
      #
      # @param [Resyma::Core::State] state The starting state
      #
      # @return [nil] Nothing
      #
      def start!(state)
        @start = state
        nil
      end

      #
      # Add a state to the accept set of the automaton
      #
      # @param [Resyma::Core::State] state An acceptable state
      #
      # @return [nil] Nothing
      #
      def accept!(state)
        @accept_set.add(state)
        nil
      end

      def build
        if @start.nil?
          raise NoStartError,
                "Cannot build a automaton without a start state"
        end

        Automaton.new(@start, @accept_set, @transition_table)
      end
    end
  end
end
