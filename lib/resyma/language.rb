require "parser"
require "resyma/parsetree"
require "resyma/core/automaton"
require "resyma/core/parsetree"
require "resyma/core/algorithm"

module Resyma
  class IllegalLanguageDefinitionError < Error; end

  class IllegalRegexError < Error; end

  class LanguageSyntaxError < Error; end

  #
  # An visitor which builds automaton. The particular syntax is defined as
  # follow:
  #
  # regex: char | seq | rep | or | opt
  # char: STRING | ID | ID '(' STRING ')'
  # seq: '(' regex (';' regex)+ ')'
  # rep: regex '..' | regex '...'
  # or: '[' regex (',' regex)+ ']'
  # opt: '[' regex ']'
  #
  class RegexBuildVistor
    #
    # Build a Resyma::Core::Automaton from an AST
    #
    # @param [Parser::AST::Node] ast An abstract syntax tree
    #
    # @return [Resyma::Core::Regexp] A regular expression
    #
    def visit(ast)
      case ast.type
      when :array
        if ast.children.length > 1
          build_or ast
        elsif ast.children.empty?
          raise IllegalRegexError, "Empty array is illegal"
        else
          build_opt ast
        end
      when :begin
        build_seq(ast)
      when :irange
        build_rep(ast, false)
      when :erange
        build_rep(ast, true)
      when :str
        value = ast.children.first
        type = Core::CONST_TOKEN_TABLE[value]
        if type.nil?
          raise IllegalRegexError,
                "Unknown constant token [#{value}]"
        end
        build_char(type, value)
      when :send
        rec, type, *args = ast.children
        raise IllegalRegexError, "Reciever #{rec} is illegal" unless rec.nil?

        if args.length > 1
          raise IllegalRegexError,
                "Two or more arguments is illegal"
        end

        return build_char(type, nil) if args.empty?

        value = args.first
        if value.type == :str
          build_char(type, value.children.first)
        else
          raise IllegalRegexError,
                "Character regex only accepts static string as value, got " +
                value.type
        end
      end
    end

    include Core::RegexpOp
    def build_char(type, value)
      rchr(Core::PTNodeMatcher.new(type, value))
    end

    def build_seq(ast)
      regex_lst = ast.children.map { |sub| visit(sub) }
      rcat(*regex_lst)
    end

    def build_rep(ast, one_or_more)
      left, right = ast.children
      raise IllegalRegexError, "Beginless range is illegal" if left.nil?
      raise IllegalRegexError, "Only endless range is legal" unless right.nil?

      regex = visit(left)
      if one_or_more
        rcat(regex, rrep(regex))
      else
        rrep(regex)
      end
    end

    def build_or(ast)
      n = ast.children.length
      unless n > 1
        raise IllegalRegexError,
              "Or-regex must contain two or more branches, but found #{n}"
      end

      regex_lst = ast.children.map { |sub| visit(sub) }
      ror(*regex_lst)
    end

    def build_opt(ast)
      value = ast.children[0]
      regex = visit(value)
      ror(reps, regex)
    end
  end

  class ActionEnvironment
    def initialize(nodes, binding, filename, lineno)
      @nodes = nodes
      @src_binding = binding
      @src_filename = filename
      @src_lineno = lineno
    end

    attr_reader :nodes, :src_binding, :src_filename, :src_lineno
  end

  #
  # Language created from single automaton and a associated action. Syntax:
  #
  #   regex >> expr
  #
  # where `regex` should adhere to syntax described in Resyma::RegexBuildVistor,
  # and `expr` is an arbitrary ruby expression. Note that
  #
  #  - Readonly variable `nodes` is visible in the `expr`, which is a `Array` of
  #    Resyma::Core::ParseTree and denotes the derivational node sequence
  #  - Readonly variables `src_binding`, `src_filename` and `src_lineno` are
  #    visible in the `expr`, which describe the environment surrounding the DSL
  #  - Variables above can be shadowed by local variables
  #  - Multiple expressions can be grouped to atom by `begin; end`
  #
  class MonoLanguage
    def initialize(automaton, action)
      @automaton = automaton
      @action = action
    end

    attr_accessor :automaton, :action

    def self.node(type, children)
      Parser::AST::Node.new(type, children)
    end

    def self.from(ast, bd, filename, lino)
      if ast.type != :send
        raise IllegalLanguageDefinitionError,
              "AST with type #{ast} cannot define a language"
      elsif ast.children[1] != :>>
        raise IllegalLanguageDefinitionError,
              "Only AST whose operator is '>>' can define a language"
      elsif ast.children.length != 3
        raise IllegalLanguageDefinitionError,
              "Language definition should be 'regex >> expr'"
      end

      regex_ast, _, action_ast = ast.children

      automaton = RegexBuildVistor.new.visit(regex_ast).to_automaton
      action_proc_ast = node :block, [
        node(:send, [nil, :lambda]),
        node(:args, [node(:arg, [:__ae__])]),
        node(:block, [
               node(:send, [node(:lvar, [:__ae__]), :instance_eval]),
               node(:args, []),
               action_ast
             ])
      ]
      action_str = Unparser.unparse(action_proc_ast)
      action = eval(action_str, bd, filename, lino)
      new automaton, action
    end
  end

  class Language
    def initialize
      # @type [Array<Resyma::MonoLanguage>]
      @mono_languages = nil
      # @type [Resyma::Core::Engine]
      @engine = nil
    end

    def syntax; end

    def build_language(procedure)
      ast, bd, filename, lino = Resyma.source_of(procedure)
      body_ast = Resyma.extract_body(ast)
      raise LanguageSyntaxError, 
            "Define your language by override method syntax" if body_ast.nil?
      if body_ast.type == :begin
        @mono_languages = body_ast.children.map do |stm_ast|
          MonoLanguage.from(stm_ast, bd, filename, lino)
        end
        @engine = Resyma::Core::Engine.new(@mono_languages.map(&:automaton))
      else
        @mono_languages = [MonoLanguage.from(body_ast, bd, filename, lino)]
        @engine = Resyma::Core::Engine.new(@mono_languages.first.automaton)
      end
    end

    def built?
      @mono_languages && @engine
    end

    #
    # Interpret the AST as current language
    #
    # @param [Parser::AST::Node] ast An abstract syntax tree
    #
    # @return [Object] Result returned by action, see Resyma::MonoLanguage for
    #   more information
    #
    def load_ast(ast, binding, filename, lineno)
      build_language(method(:syntax)) unless built?
      parsetree = Core::DEFAULT_CONVERTER.convert(ast)
      @engine.traverse!(parsetree)
      accepted_set = @engine.accepted_tuples(parsetree)
      tuple4 = accepted_set.min_by(&:belongs_to)
      if tuple4.nil?
        raise LanguageSyntaxError,
              "The code does not adhere to syntax defined by #{self.class}"
      end
      dns = @engine.backtrack_for(parsetree, tuple4)
      nodes = dns.map { |t| @engine.node_of(parsetree, t.p_) }
      action = @mono_languages[tuple4.belongs_to].action
      ae = ActionEnvironment.new(nodes, binding, filename, lineno)
      action.call(ae)
    end

    #
    # Load a block as DSL. Note that argument of the block will be ignored.
    #
    # @return [Object] Result of the evaluation, defined by current DSL
    #
    def load(&block)
      ast, bd, filename, = Resyma.source_of(block)
      body_ast = Resyma.extract_body(ast)
      lino = body_ast.loc.expression.line
      load_ast(body_ast, bd, filename, lino)
    end

    #
    # Initialize a new instance without argument and call `#load`
    #
    # @return [Object] Result of the evaluation.
    # @see See #load
    #
    def self.load(&block)
      new.load(&block)
    end
  end
end
