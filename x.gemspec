# frozen_string_literal: true

# The version every gem in this repository is released at
version = File.read(File.expand_path("VERSION", __dir__)).strip
# The requirement on the other gems of this repository, which is this version alone, as the five gems are built,
# tested, and released together at each version, so x installs the set of them that was tested together
sibling_requirement = "= #{version}"

Gem::Specification.new do |spec|
  spec.name = "x"
  spec.version = version
  spec.authors = ["Erik Berlin"]
  spec.email = ["sferik@gmail.com"]

  spec.summary = "A Ruby interface to the X API."
  spec.homepage = "https://sferik.github.io/x-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"
  spec.platform = Gem::Platform::RUBY

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "bug_tracker_uri" => "https://github.com/sferik/x-ruby/issues",
    "changelog_uri" => "https://github.com/sferik/x-ruby/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://sferik.github.io/x-ruby/api/",
    "funding_uri" => "https://github.com/sponsors/sferik/",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/sferik/x-ruby"
  }

  # CONTRIBUTING.md is for working on the repository, not for using the gem
  spec.files = Dir.glob([
    "lib/**/*.rb",
    "sig/*.rbs",
    "sig/manifest.yaml",
    ".yardopts",
    "*.md",
    "LICENSE.txt"
  ], base: __dir__) - ["CONTRIBUTING.md"]
  spec.require_paths = ["lib"]
  spec.add_dependency("x-core", sibling_requirement)
  spec.add_dependency("x-uploads", sibling_requirement)
  spec.add_dependency("x-streams", sibling_requirement)
  spec.add_dependency("x-resources", sibling_requirement)
end
