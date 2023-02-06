require "set"
require "resyma/core/utilities"
require "resyma/core/automaton/definition"
require "resyma/core/automaton/builder"

module Resyma
  module Core
    class EpsilonClass
      include Matchable
    end

    Epsilon = EpsilonClass.new

    class Automaton
      #
      # Computes the epsilon-closure of `state`
      #
      # @param [Set<Resyma::Core::State>] state_set Starting set of state
      #
      # @return [Set<Resyma::Core::State>] The epsilon-closure
      #
      def eclose(state_set)
        queue = state_set.to_a
        closure = queue.to_set
        until queue.empty?
          next_state = queue.shift
          transition_table.candidates(next_state).each do |can|
            next unless can.condition.equal?(Epsilon) &&
                        !closure.include?(can.destination)

            closure.add(can.destination)
            queue.push(can.destination)
          end
        end
        closure
      end

      def possible_nonepsilon_conditions(state)
        transition_table.candidates(state).map(&:condition).select do |cond|
          !cond.equal?(Epsilon)
        end.to_set
      end

      #
      # Computes next epsilon-closures connecting with `epsilon_closure`
      #
      # @param [Set<Resyma::Core::State>] epsilon_closure Current closure
      # @param [Hash] closure_map Hash map from closures to states, may be
      #   modified
      # @param [Resyma::Core::AutomatonBuilder] ab Builder of the new DFA, may
      #   be modified
      #
      # @return [Array<Set>] New unrecorded epsilon-closures
      #
      def generate_reachable_epsilon_closures(epsilon_closure, closure_map, ab)
        current_state = closure_map[epsilon_closure]
        condition_sets = epsilon_closure.map do |state|
          possible_nonepsilon_conditions(state)
        end
        new_closures = []
        Utils.big_union(condition_sets).each do |cond|
          new_closure = Set[]
          epsilon_closure.each do |state|
            # [WARN] We are using a `matchable` as a `matched value, which may
            # cause unexpected consequence
            dst = destination(state, cond)
            new_closure.add dst unless dst.nil?
          end
          raise "Internal error: No destination states" if new_closure.empty?

          new_closure = eclose(new_closure)
          if closure_map.include?(new_closure)
            recorded_state = closure_map[new_closure]
            ab.add_transition!(current_state, cond, recorded_state)
          else
            new_state = ab.new_state!
            closure_map[new_closure] = new_state
            ab.add_transition!(current_state, cond, new_state)
            new_closures.push new_closure
          end
        end
        new_closures
      end

      def to_DFA
        ab = AutomatonBuilder.new
        start_closure = eclose(Set[start])
        start_state = ab.new_state!
        ab.start! start_state
        closure_map = { start_closure => start_state }
        queue = [start_closure]
        until queue.empty?
          next_closure = queue.shift
          unrecorded_closures = generate_reachable_epsilon_closures(
            next_closure, closure_map, ab
          )
          queue += unrecorded_closures
        end
        closure_map.each do |closure, state|
          ab.accept! state if closure.any? { |s| accept? s }
        end
        ab.build
      end

      def has_epsilon?
        transition_table.table.values.each do |cans|
          cans.each do |can|
            return true if can.condition.equal?(Epsilon)
          end
        end
        false
      end
    end
  end
end
