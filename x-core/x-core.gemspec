# frozen_string_literal: true

# The version every gem in this repository is released at
version = File.read(File.expand_path("../VERSION", __dir__)).strip

Gem::Specification.new do |spec|
  spec.name = "x-core"
  spec.version = version
  spec.authors = ["Erik Berlin"]
  spec.email = ["sferik@gmail.com"]

  spec.summary = "The HTTP layer of the X gem: authentication, requests, and errors."
  spec.homepage = "https://sferik.github.io/x-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"
  spec.platform = Gem::Platform::RUBY

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "bug_tracker_uri" => "https://github.com/sferik/x-ruby/issues",
    "changelog_uri" => "https://github.com/sferik/x-ruby/blob/main/x-core/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/gems/x-core/",
    "funding_uri" => "https://github.com/sponsors/sferik/",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/sferik/x-ruby/tree/main/x-core"
  }

  spec.files = Dir.glob([
    "lib/**/*.rb",
    "sig/*.rbs",
    "sig/manifest.yaml",
    "*.md",
    "LICENSE.txt"
  ], base: __dir__)
  spec.require_paths = ["lib"]
  # net-http is a default gem, and the 0.6 that Ruby 3.4 ships cannot request a host named by an IPv6 literal,
  # such as a base_url of http://[::1]:8080/, so the version that can is asked for here
  spec.add_dependency("net-http", ">= 0.8")
  spec.add_dependency("simple_oauth", "~> 1.0")
end
