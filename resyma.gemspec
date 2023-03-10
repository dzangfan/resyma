# frozen_string_literal: true

require_relative "lib/resyma/version"

Gem::Specification.new do |spec|
  spec.name = "resyma"
  spec.version = Resyma::VERSION
  spec.authors = ["Li Dzangfan"]
  spec.email = ["dzangfan.li@gmail.com"]

  spec.summary = "A regular syntax matcher"
  spec.description = "A regular syntax matcher facilitating DSL's construction"
  spec.homepage = "https://github.com/dzangfan/resyma"
  spec.required_ruby_version = ">= 2.6.0"
  spec.license = "GPL-3.0-only"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\A#{spec.bindir}/}) do |f|
    File.basename(f)
  end
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  spec.add_dependency "parser", "~> 3.0"
  spec.add_dependency "ruby-graphviz", "~> 1.2"
  spec.add_dependency "unparser", "~> 0.6"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "yard", "~> 0.9.26"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
