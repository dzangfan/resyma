require "set"
require "parser/current"

module Resyma
  module Core
    SourceLocator = Struct.new("SourceDetector", :matcher, :locate)

    SOURCE_LOCATORS = []

    def self.def_source_locator(regexp, &block)
      SOURCE_LOCATORS.unshift SourceLocator.new(regexp, block)
    end

    #
    # Locate the AST of a callable object
    #
    # @param [#source_location] procedure A callable object, particular a
    #   instance of Proc or Method
    #
    # @return [nil, Parser::AST::Node] AST of the procedure, or nil if cannot
    #   locate its source
    #
    def self.locate(procedure)
      if procedure.respond_to? :source_location
        filename, lino = procedure.source_location
        SOURCE_LOCATORS.each do |locator|
          if locator.matcher.match?(filename)
            return locator.locate.call(procedure, filename, lino)
          end
        end
      end

      nil
    end

    CALLABLE_TYPES = Set[:def, :defs, :block]

    def self.line_number_of_callable(ast)
      case ast.type
      when Set[:def, :defs] then ast.loc.keyword.line
      when :block then ast.loc.begin.line
      end
    end

    def self.locate_possible_procedures(ast, lino)
      return [] unless ast.is_a?(Parser::AST::Node)

      procs = []
      if CALLABLE_TYPES.include?(ast.type) &&
         line_number_of_callable(ast) == lino
        procs.push ast
      end
      ast.children.each do |sub|
        procs += locate_possible_procedures(sub, lino)
      end
      procs
    end

    class MultipleProcedureError < Resyma::Error; end

    def_source_locator(/^.*$/) do |_, filename, lino|
      tree = Parser::CurrentRuby.parse_file(filename)
      procs = locate_possible_procedures(tree, lino)
      case procs.size
      when 1 then procs[0]
      when 0 then nil
      else raise MultipleProcedureError,
                 "Detected multiple procedures in [#{filename}:#{lino}], " +
                 "which is unsupported currently"
      end
    end
  end
end
