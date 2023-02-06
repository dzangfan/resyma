module Resyma
  module Core
    class Tuple4
      def initialize(p, q, p_, q_, belongs_to: 0)
        @p = p
        @q = q
        @p_ = p_
        @q_ = q_
        @belongs_to = belongs_to
      end

      attr_accessor :p, :q, :p_, :q_, :belongs_to
    end

    class Tuple2
      def initialize(p, q, belongs_to: 0)
        @p = p
        @q = q
        @belongs_to = belongs_to
      end

      attr_accessor :p, :q, :belongs_to
    end
  end
end
