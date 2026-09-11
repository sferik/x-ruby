require_relative "lib/x/media/version"

Gem::Specification.new do |spec|
  spec.name = "x-media"
  spec.version = X::MediaUploader::VERSION
  spec.authors = ["Erik Berlin"]
  spec.email = ["sferik@gmail.com"]

  spec.summary = "Media uploads for the X gem: images, GIFs, videos, subtitles, and profile images and banners."
  spec.homepage = "https://sferik.github.io/x-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.platform = Gem::Platform::RUBY

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "bug_tracker_uri" => "https://github.com/sferik/x-ruby/issues",
    "changelog_uri" => "https://github.com/sferik/x-ruby/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/gems/x-media/",
    "funding_uri" => "https://github.com/sponsors/sferik/",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/sferik/x-ruby/tree/main/x-media"
  }

  spec.files = Dir[
    "lib/**/*.rb",
    "sig/*.rbs",
    "*.md",
    "LICENSE.txt"
  ]
  spec.require_paths = ["lib"]
  spec.add_dependency("x-core", X::MediaUploader::VERSION.to_s)
end
