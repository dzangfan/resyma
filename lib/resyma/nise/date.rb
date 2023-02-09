require "resyma"
require "date"

#
# DSL reading dates
#
class LangDate < Resyma::Language
  def syntax
    id("today") >> Date.today

    (int; id("/"); int; id("/"); int) >> begin
      year = nodes[0].to_ruby
      month = nodes[2].to_ruby
      day = nodes[4].to_ruby
      Date.new(year, month, day)
    end

    (numop; numbase; "."; [id("day"), id("month"), id("year")]) >> begin
      op, num, _, unit = nodes
      sig = op.to_literal == "+" ? 1 : -1
      val = num.to_literal.to_i * sig
      case unit.to_literal
      when "day" then Date.today.next_day(val)
      when "month" then Date.today.next_month(val)
      when "year" then Date.today.next_year(val)
      end
    end

    id("yesterday") >> LangDate.load { -1.day }
    id("tomorrow") >> LangDate.load { +1.day }
  end
end

def date(&block)
  LangDate.load(&block)
end

class LangTimeline < Resyma::Language
  def syntax
    (array; id("-"); str)... >> begin
      items = []
      until nodes.empty?
        date, _, text = (1..3).map { nodes.shift }
        raise SyntaxError if date.children.length != 3 # '[' DATE ']'

        date = LangDate.new.load_parsetree!(date.children[1], src_binding,
                                            src_filename, src_lineno)
        items.push [date, text.to_ruby]
      end
      items
    end
  end
end
