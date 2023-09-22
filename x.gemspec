require_relative "lib/x/version"

Gem::Specification.new do |spec|
  spec.name = "x"
  spec.version = X::VERSION
  spec.authors = ["Erik Berlin"]
  spec.email = ["sferik@gmail.com"]

  spec.summary = "A Ruby interface to the X API."
  spec.homepage = "https://sferik.github.io/x-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"
  spec.platform = Gem::Platform::RUBY

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true",
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/sferik/x-ruby",
    "changelog_uri" => "https://github.com/sferik/x-ruby/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/sferik/x-ruby/issues",
    "documentation_uri" => "https://rubydoc.info/gems/x/",
  }

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
