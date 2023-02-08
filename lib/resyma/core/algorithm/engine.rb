require "resyma/core/utilities"
require "resyma/core/automaton"
require "resyma/core/algorithm/tuple"

module Resyma
  module Core
    #
    # The engine of the matching algorithm
    #
    class Engine
      #
      # Create an instance of the algorithmic engine
      #
      # @param [Array<Resyma::Core::Automaton>, Resyma::Core::Automaton]
      #   automata A list of automata
      #
      def initialize(automata)
        automata = [automata] if automata.is_a?(Automaton)
        raise TypeError, "Need a list of automata" unless automata.is_a?(Array)

        @automata = automata
      end

      #
      # Determine the type of the node corresponding step 2 of the algorithm
      #
      # @param [Resyma::Core::ParseTree] parsetree A node of parse tree
      #
      # @return [:a, :b, :c] Type of the node
      #
      def node_type(parsetree)
        if parsetree.root?          then :a
        elsif parsetree.index.zero? then :b
        else
          :c
        end
      end

      #
      # Right-most path of the tree
      #
      # @param [Resyma::Core::ParseTree] parsetree A parse tree
      #
      # @return [Set<Resyma::Core::ParseTree>] A set of nodes on the RMP
      #
      def RMP(parsetree)
        if parsetree.leaf?
          Set[parsetree]
        else
          Set[parsetree] | RMP(parsetree.children.last)
        end
      end

      #
      # Step 2 of the algorithm
      #
      # @param [Resyma::Core::ParseTree] node A parse tree node
      #
      # @return [nil] Nothing
      #
      def assign_start!(node)
        @automata.each_with_index do |automaton, idx|
          node.field.start[idx] =
            case node_type(node)
            when :a
              Set[Tuple2.new(-1, automaton.start, belongs_to: idx)]
            when :b
              node.parent.field.start[idx]
            when :c
              # @type [Resyma::Core::ParseTree]
              brother = node.parent.children[node.index - 1]
              Utils.big_union(RMP(brother).map do |node_|
                node_.field.trans[idx].map do |tuple4|
                  Tuple2.new(tuple4.p_, tuple4.q_, belongs_to: idx)
                end
              end)
            end
        end
      end

      #
      # Step 3 of the algorithm
      #
      # @param [Resyma::Core::ParseTree] node A parse tree
      #
      # @return [nil] Nothing
      #
      def assign_trans!(node)
        @automata.each_with_index do |automaton, idx|
          node.field.trans[idx] = node.field.start[idx].map do |tuple2|
            next_q = automaton.destination(tuple2.q, node)
            next_q and Tuple4.new(tuple2.p, tuple2.q, node.field.id, next_q,
                                  belongs_to: idx)
          end.compact.to_set
        end
      end

      CACHE_INDEX_TO_NODE = "ALGO_IDX_NODE_MAP".freeze

      #
      # Find the parse tree through its ID
      #
      # @param [Resyma::Core::ParseTree] parsetree A parse tree processed by
      #   `#traverse!`
      # @param [Integer] id Depth-first ordered ID, based on 0
      #
      # @return [Resyma::Core::ParseTree, nil] Result, or nil if node with `id`
      #   does not exist
      #
      def node_of(parsetree, id)
        parsetree.cache[Engine::CACHE_INDEX_TO_NODE][id]
      end

      #
      # Traverse the parse tree once and modify fields for every nodes
      #
      # @param [Resyma::Core::ParseTree] parsetree A parse tree
      #
      # @return [nil] Nothing
      #
      def traverse!(parsetree)
        id = 0
        parsetree.cache[Engine::CACHE_INDEX_TO_NODE] = {}
        parsetree.depth_first_each do |tree|
          tree.field.id = id
          assign_start! tree
          assign_trans! tree
          parsetree.cache[Engine::CACHE_INDEX_TO_NODE][id] = tree
          id += 1
        end
      end

      #
      # Compute accepted 4-tuples in the processed tree
      #
      # @param [Resyma::Core::ParseTree] parsetree A parse tree processed by
      #   `#traverse!`
      #
      # @return [Set<Resyma::Core::Tuple4>] A set of 4-tuples
      #
      def accepted_tuples(parsetree)
        Utils.big_union(RMP(parsetree).map do |node|
          Utils.big_union(node.field.trans.values.map do |set_of_tuple4|
            set_of_tuple4.select do |tuple4|
              @automata[tuple4.belongs_to].accept?(tuple4.q_)
            end.to_set
          end)
        end)
      end

      #
      # Backtrack the derivational node sequence terminating at the 4-tuple
      #
      # @param [Resyma::Core::ParseTree] parsetree A processed parse tree
      # @param [Resyma::Core::Tuple4] accepted_tuple4 A 4-tuple derived from
      #   `#accepted_tuples`
      #
      # @return [Array<Resyma::Core::Tuple4>] A derivational node sequence
      #
      def backtrack_for(parsetree, tuple4)
        if tuple4.p == -1
          [tuple4]
        else
          # @type [Resyma::Core::ParseTree]
          prev = parsetree.cache[Engine::CACHE_INDEX_TO_NODE][tuple4.p]
          prev_tuple4 = prev.field.trans[tuple4.belongs_to].find do |candidate|
            candidate.p_ == tuple4.p && candidate.q_ == tuple4.q
          end
          backtrack_for(parsetree, prev_tuple4) + [tuple4]
        end
      end

      #
      # Backtrack the derivational node sequence(s) of a parse tree processed by
      #   the algorithm
      #
      # @param [Resyma::Core::ParseTree] parsetree A parse tree processed by
      #   `#traverse!`
      # @param [Set<Resyma::Core::Tuple4>] terminal_tuples Accepted sets derived
      #   from `#accepted_tuples`
      #
      # @return [Array<Array<Resyma::Core::Tuple4>] Derivational node sequences
      #
      def backtrack(parsetree, terminal_tuples = accepted_tuples(parsetree))
        terminal_tuples.map { |tuple4| backtrack_for(parsetree, tuple4) }
      end
    end
  end
end
