# The version every gem in this repository is released at
version = File.read(File.expand_path("../VERSION", __dir__)).strip

Gem::Specification.new do |spec|
  spec.name = "x-objects"
  spec.version = version
  spec.authors = ["Erik Berlin"]
  spec.email = ["sferik@gmail.com"]

  spec.summary = "The object layer of the X gem: users, posts, lists, direct messages, and cursors."
  spec.homepage = "https://sferik.github.io/x-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.platform = Gem::Platform::RUBY

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "bug_tracker_uri" => "https://github.com/sferik/x-ruby/issues",
    "changelog_uri" => "https://github.com/sferik/x-ruby/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/gems/x-objects/",
    "funding_uri" => "https://github.com/sponsors/sferik/",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/sferik/x-ruby/tree/main/x-objects"
  }

  spec.files = Dir[
    "lib/**/*.rb",
    "sig/*.rbs",
    "*.md",
    "LICENSE.txt"
  ]
  spec.require_paths = ["lib"]
end
