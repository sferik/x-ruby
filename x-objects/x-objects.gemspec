# frozen_string_literal: true

# The version every gem in this repository is released at
version = File.read(File.expand_path("../VERSION", __dir__)).strip
# The requirement on the other gems of this repository, such as ">= 1.0.0" and "< 2" for 1.0.0, which this version and
# any later 1.x satisfy, so a gem never installs beside an earlier release of the gems it depends on than its own
sibling_requirement = [">= #{version}", "< #{Gem::Version.new(version).segments.first.succ}"]

Gem::Specification.new do |spec|
  spec.name = "x-objects"
  spec.version = version
  spec.authors = ["Erik Berlin"]
  spec.email = ["sferik@gmail.com"]

  spec.summary = "The object layer of the X gem: users, posts, lists, direct messages, and cursors."
  spec.homepage = "https://sferik.github.io/x-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"
  spec.platform = Gem::Platform::RUBY

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "bug_tracker_uri" => "https://github.com/sferik/x-ruby/issues",
    "changelog_uri" => "https://github.com/sferik/x-ruby/blob/main/x-objects/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/gems/x-objects/",
    "funding_uri" => "https://github.com/sponsors/sferik/",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/sferik/x-ruby/tree/main/x-objects"
  }

  spec.files = Dir.glob([
    "lib/**/*.rb",
    "sig/*.rbs",
    "sig/manifest.yaml",
    ".yardopts",
    "*.md",
    "LICENSE.txt"
  ], base: __dir__)
  spec.require_paths = ["lib"]
  spec.add_dependency("x-core", *sibling_requirement)
end
