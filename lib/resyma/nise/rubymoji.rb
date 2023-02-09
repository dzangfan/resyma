require "resyma"

class LangRubymoji < Resyma::Language
  def syntax
    (id("O"); "."; id("O"); str("??")) >> "🤔"
    (id("o"); id("^"); id("o")) >> "🙃"
    (id("Zzz"); ".."; "("; id("x"); "."; id("x"); ")") >> "😴"
  end
end

def rubymoji(&block)
  LangRubymoji.load(&block)
end