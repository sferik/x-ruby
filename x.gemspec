require_relative "lib/x/version"

Gem::Specification.new do |spec|
  spec.name = "x"
  spec.version = X::VERSION
  spec.authors = ["Erik Berlin"]
  spec.email = ["sferik@gmail.com"]

  spec.summary = "A Ruby interface to the X API."
  spec.homepage = "https://sferik.github.io/x-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.6"
  spec.platform = Gem::Platform::RUBY

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true",
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/sferik/x-ruby",
    "changelog_uri" => "https://github.com/sferik/x-ruby/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/sferik/x-ruby/issues",
    "documentation_uri" => "https://rubydoc.info/gems/x/"
  }

  spec.files = Dir[
    "bin/*",
    "lib/**/*.rb",
    # "sig/*.rbs",
    "*.md",
    "LICENSE.txt"
  ]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
