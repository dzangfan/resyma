require "optparse"
require "resyma"
require "ruby-graphviz"
require "parser/current"

class Visualizer
  def initialize
    @viz = GraphViz.new(:G, type: :graph)
    @id_pool = 0
  end

  def shorten(str, limit = 10)
    str = str.to_s
    if str.length > limit
      str[0...limit] + "..."
    else
      str
    end
  end

  def label_of(parsetree)
    label = parsetree.symbol
    if parsetree.leaf?
      "#{label}(#{shorten(parsetree.children.first)})"
    else
      label
    end
  end

  def def_node(parsetree)
    @id_pool += 1
    label = label_of(parsetree)
    @viz.add_node(@id_pool.to_s, label: label)
  end

  #
  # @param [Resyma::Core::ParseTree] parsetree
  #
  def viz!(parsetree, node = nil)
    node = def_node(parsetree) if node.nil?
    return if parsetree.leaf?

    parsetree.children.each do |sub|
      sub_node = def_node(sub)
      @viz.add_edge(node, sub_node)
      viz!(sub, sub_node)
    end
  end

  def output(filename)
    @viz.output(png: filename)
  end
end

def launch
  output_filename = "./resyma-parsetree.png"

  OptionParser.new do |opts|
    opts.on("-o", "--output FILE",
            "PNG containing the resulting tree") do |file|
      output_filename = file
    end
    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end
  end.parse!

  source = $stdin.read
  ast = Parser::CurrentRuby.parse(source)
  begin
    pt = Resyma::Core::DEFAULT_CONVERTER.convert(ast)
    viz = Visualizer.new
    viz.viz!(pt)
    viz.output(output_filename)
  rescue Resyma::Core::ConversionError
    puts "Cannot convert the AST: #{$!}"
  end
end
