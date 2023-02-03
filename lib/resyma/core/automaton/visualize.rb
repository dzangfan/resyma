module Resyma
  module Core
    def Epsilon.to_s
      "ε"
    end

    class Automaton
      def to_lwg(port = $>)
        transition_table.table.each do |state, candidates|
          candidates.each do |can|
            port << "#{state.id} - #{can.destination.id}\n"
            port <<
              %(move.#{state.id}.#{can.destination.id} = "#{can.condition}"\n)
          end
        end
        accept_set.each do |state|
          port << "accept.#{state.id}\n"
        end
        port << "start.from.#{start.id}\n"
      end
    end
  end
end
