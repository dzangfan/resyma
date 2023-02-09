require "resyma"
require "ruby-graphviz"
require "resyma/core/automaton"
require "parser/current"

class Visualizer
  def initialize(automaton)
    @viz = GraphViz.new(:G, type: :graph)
    @viz[:rankdir] = "LR"
    @id_pool = 0
    # @type [Resyma::Core::Automaton]
    @automaton = automaton
    @node_cache = {}
  end

  def def_state(state)
    @id_pool += 1
    label = state.id.to_s
    shape = @automaton.accept?(state) ? "doublecircle" : "circle"
    @viz.add_node(@id_pool.to_s, label: label, shape: shape)
  end

  def shorten(str, limit = 10)
    str = str.to_s
    if str.length > limit
      str[0...limit] + "..."
    else
      str
    end
  end

  def node_of(state)
    node = @node_cache[state]
    return node if node

    node = def_state(state)
    @node_cache[state] = node
    node
  end

  def viz_matcher(node_matcher)
    rez = node_matcher.type.to_s
    rez += "(#{shorten(node_matcher.value)})" if node_matcher.value
    rez
  end

  def viz!
    @automaton.transition_table.table.each do |src, value|
      src_node = node_of src
      value.each do |can|
        node_matcher = can.condition
        dest = can.destination
        dest_node = node_of(dest)
        @viz.add_edge(src_node, dest_node, { label: viz_matcher(node_matcher) })
      end
    end
  end

  def output(filename)
    @viz.output(png: filename)
  end
end

def launch
  output_filename = "./resyma-automaton.png"

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
  automaton = Resyma::RegexBuildVistor.new.visit(ast).to_automaton
  viz = Visualizer.new(automaton)
  viz.viz!
  viz.output(output_filename)
end
