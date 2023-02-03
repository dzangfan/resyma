require "set"

module Resyma
  module Core
    module Utils
      def self.big_union(sets)
        union = Set[]
        sets.each { |set| union.merge(set) }
        union
      end

      #
      # Whether an automaton accepts the input
      #
      # @param [Resyma::Core::Automaton] automaton An well-formed automaton
      # @param [Array] input_array A list of input tokens
      #
      # @return [true,false] Result
      #
      def self.automaton_accept?(automaton, input_array)
        current_state = automaton.start
        input_array.each do |word|
          current_state = automaton.destination(current_state, word)
          return false if current_state.nil?
        end
        automaton.accept? current_state
      end
    end
  end
end
