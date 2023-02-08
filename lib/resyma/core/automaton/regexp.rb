require "resyma/core/automaton/builder"

module Resyma
  module Core
    class Regexp
      #
      # Converts self to automaton, which is implemented by subclasses. Note
      # that only add states and transitions by the automaton builder, do not
      # modify starting state and accept set
      #
      # @param [Resyma::Core::AutomatonBuilder] ab Output automaton
      # @param [Resyma::Core::State] start_state Starting state, every
      #   implements should work starting from this state
      #
      # @return [Resyma::Core::State] Ending state, every implements should end
      #   their automaton with a single acceptable state
      #
      def inject(ab, start_state)
        raise NotImplementedError
      end

      #
      # Convert the regexp to a DFA
      #
      # @return [Resyma::Core::Automaton] A automaton without `Epsilon`
      #
      def to_automaton(eliminate_epsilon = true)
        ab = AutomatonBuilder.new
        start = ab.new_state!
        ab.start! start
        accept = inject ab, start
        ab.accept! accept
        result = ab.build
        if eliminate_epsilon
          result.to_DFA
        else
          result
        end
      end
    end

    class RegexpConcat < Regexp
      #
      # Concatentate a list of regexps
      #
      # @param [Array<Regexp>] regexp_list A list of instances of Regexp
      #
      def initialize(regexp_list)
        @regexp_list = regexp_list
      end

      attr_reader :regexp_list

      def ==(other)
        other.is_a?(self.class) && other.regexp_list == @regexp_list
      end

      def inject(ab, start_state)
        current_start = start_state
        @regexp_list.each do |regexp|
          current_start = regexp.inject(ab, current_start)
        end
        current_start
      end
    end

    class RegexpSelect < Regexp
      #
      # Select one regexp from a list of regexps
      #
      # @param [Array<Regexp>] regexp_list A list of instances of Regexp
      #
      def initialize(regexp_list)
        @regexp_list = regexp_list
      end

      attr_reader :regexp_list

      def ==(other)
        other.is_a?(self.class) && other.regexp_list == @regexp_list
      end

      def inject(ab, start_state)
        accept = ab.new_state!
        @regexp_list.each do |regexp|
          option_start = ab.new_state!
          ab.add_transition!(start_state, Epsilon, option_start)
          option_end = regexp.inject(ab, option_start)
          ab.add_transition!(option_end, Epsilon, accept)
        end
        accept
      end
    end

    class RegexpRepeat < Regexp
      #
      # Repeat the regexp zero, one, or more times
      #
      # @param [Regexp] regexp A instance of Regexp
      #
      def initialize(regexp)
        @regexp = regexp
      end

      attr_reader :regexp

      def ==(other)
        other.is_a?(self.class) && other.regexp == @regexp
      end

      def inject(ab, start_state)
        accept = @regexp.inject(ab, start_state)
        ab.add_transition!(start_state, Epsilon, accept)
        ab.add_transition!(accept, Epsilon, start_state)
        accept
      end
    end

    class RegexpSomething < Regexp
      #
      # Matches what the matchable matches
      #
      # @param [Resyma::Core::Matchable] matchable A matchable object
      #
      def initialize(matchable)
        @condition = matchable
      end

      attr_reader :condition

      def ==(other)
        other.is_a?(self.class) && other.condition == @condition
      end

      def inject(ab, start_state)
        accept = ab.new_state!
        ab.add_transition!(start_state, @condition, accept)
        accept
      end
    end

    class RegexpNothing < Regexp

      def ==(other)
        other.is_a?(RegexpNothing)
      end

      def inject(_ab, start_state)
        start_state
      end
    end

    module RegexpOp
      def rcat(*regexps)
        RegexpConcat.new(regexps)
      end

      def ror(*regexps)
        RegexpSelect.new(regexps)
      end

      def rrep(regexp)
        RegexpRepeat.new(regexp)
      end

      def rchr(matchable)
        RegexpSomething.new(matchable)
      end

      def reps
        RegexpNothing.new
      end
    end
  end
end
