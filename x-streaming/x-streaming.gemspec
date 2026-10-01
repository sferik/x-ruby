# frozen_string_literal: true

# The version every gem in this repository is released at
version = File.read(File.expand_path("../VERSION", __dir__)).strip
# The requirement on the other gems of this repository, such as "~> 1.0" for 1.0.0, which any later 1.x satisfies
sibling_requirement = Gem::Version.new(version).approximate_recommendation

Gem::Specification.new do |spec|
  spec.name = "x-streaming"
  spec.version = version
  spec.authors = ["Erik Berlin"]
  spec.email = ["sferik@gmail.com"]

  spec.summary = "Streaming for the X gem: the sample and filtered streams, reconnected as X recommends, and the rules of the filtered stream."
  spec.homepage = "https://sferik.github.io/x-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"
  spec.platform = Gem::Platform::RUBY

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "bug_tracker_uri" => "https://github.com/sferik/x-ruby/issues",
    "changelog_uri" => "https://github.com/sferik/x-ruby/blob/main/x-streaming/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/gems/x-streaming/",
    "funding_uri" => "https://github.com/sponsors/sferik/",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/sferik/x-ruby/tree/main/x-streaming"
  }

  spec.files = Dir.glob([
    "lib/**/*.rb",
    "sig/*.rbs",
    "sig/manifest.yaml",
    "*.md",
    "LICENSE.txt"
  ], base: __dir__)
  spec.require_paths = ["lib"]
  spec.add_dependency("x-core", sibling_requirement)
end
