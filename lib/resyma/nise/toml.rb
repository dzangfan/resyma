require "resyma"

class LangTOMLBuilder
  def initialize
    @root = make_hash
    @prefix = []
  end

  def make_hash
    Hash.new { |hash, key| hash[key] = make_hash }
  end

  attr_accessor :root, :prefix

  def add!(path, value)
    raise SyntaxError if path.empty?
    abs_path = @prefix + path
    cur = @root
    abs_path[...-1].each do |name|
      cur = cur[name.to_sym]
    end
    cur[abs_path.last.to_sym] = value
  end
end

class LangTOMLNamespace < Resyma::Language
  def syntax
    ("["; id; ("."; id)..; "]") >> begin
      nodes.select { |n| n.symbol == :id }.map { |n| n.to_literal }
    end
  end
end

class LangTOML < Resyma::Language
  def syntax
    [array, 
     (id; ("."; id)..; "="; [int, str, "true", "false", array, hash])]... >>
    begin
      bdr = LangTOMLBuilder.new
      until nodes.empty?
        car = nodes.shift
        if car.symbol == :array
          namespace = 
            LangTOMLNamespace.new.load_parsetree!(
              car, src_binding, src_filename, src_lineno
            )
          bdr.prefix = namespace
        else
          path = [car]
          car = nodes.shift
          until car.symbol == :eq
            path.push car if car.symbol == :id
            car = nodes.shift
          end
          value = nodes.shift
          bdr.add!(path.map(&:to_literal), 
                   value.to_ruby(src_binding, src_filename, src_lineno))
        end
      end
      bdr.root
    end
  end
end