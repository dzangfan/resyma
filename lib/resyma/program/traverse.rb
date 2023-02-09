require "resyma"
require_relative "parsetree"
require "resyma/nise/date"
require "resyma/nise/toml"
require "resyma/nise/rubymoji"

class FieldVisualizer < Visualizer
  def label_of(parsetree)
    label = super(parsetree)
    id = parsetree.field.id
    start = parsetree.field.start.values.map(&:to_a).flatten
    trans = parsetree.field.trans.values.map(&:to_a).flatten
    label = "#{label}\##{id}\\n"

    unless start.empty?
      label += "START\n"
      start.each do |tuple2|
        label += "#{tuple2.p},#{tuple2.q.id}/#{tuple2.belongs_to}\\n"
      end
    end

    unless trans.empty?
      label += "TRANS\\n"
      trans.each do |tuple4|
        label +=
          "#{tuple4.p},#{tuple4.q.id},#{tuple4.p_},#{tuple4.q_.id}" +
          "/#{tuple4.belongs_to}\\n"
      end
    end
    label
  end
end

def launch

  option = {
    output_filename: "./resyma-traverse.png",
    language: LangDate
  }

  available_languages = {
    "date" => LangDate,
    "toml" => LangTOML,
    "rubymoji" => LangRubymoji
  }

  OptionParser.new do |opts|
    opts.on("-o", "--output FILE",
            "PNG containing the resulting tree") do |file|
              option[:output_filename] = file
            end
    opts.on("-l", "--language LANG",
            "Language used to traverse the tree") do |lang|
              option[:language] = available_languages[lang]
              if option[:language].nil?
                raise "Unknown language #{lang}. " +
                      "Available languages are #{available_languages.keys}"
              end
            end
    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end
  end.parse!

  puts "Input source of #{option[:language]}"
  source = $stdin.read
  ast = Parser::CurrentRuby.parse(source)
  pt = Resyma::Core::DEFAULT_CONVERTER.convert(ast)
  lang = option[:language].new
  lang.build_language(lang.method(:syntax))
  engine = lang.engine
  engine.traverse!(pt)
  viz = FieldVisualizer.new
  viz.viz!(pt)
  viz.output(option[:output_filename])
end
