# frozen_string_literal: true

require "bundler/gem_tasks"

# The gems in this repository, in dependency order, released in lockstep
GEMS = {"x-core" => "x-core", "x-uploads" => "x-uploads", "x-streams" => "x-streams", "x-resources" => "x-resources", "x" => "."}.freeze

# The one file that holds the version, which every gemspec reads
VERSION_FILE = File.expand_path("VERSION", __dir__)

# The files that hold each gem's runtime version constant, written from VERSION_FILE
VERSION_CONSTANT_FILES = %w[lib/x/version.rb x-core/lib/x/core/version.rb x-uploads/lib/x/uploads/version.rb
  x-streams/lib/x/streams/version.rb x-resources/lib/x/resources/version.rb].map { |path| File.expand_path(path, __dir__) }.freeze

# The version in VERSION_FILE
def version
  File.read(VERSION_FILE).strip
end

# The version a version.rb file holds
def version_in(file)
  File.read(file)[/VERSION = "([^"]+)"/, 1]
end

desc "Write the version in VERSION into each gem's version.rb"
task :update_versions do
  VERSION_CONSTANT_FILES.each do |file|
    File.write(file, File.read(file).sub(/VERSION = "[^"]+"/, %(VERSION = "#{version}")))
  end
end

desc "Check that each gem's version.rb holds the version in VERSION"
task :check_versions do
  stale = VERSION_CONSTANT_FILES.reject { |file| version_in(file).eql?(version) }
  abort "Run `rake update_versions`: #{stale.join(", ")} do not hold #{version}" unless stale.empty?
end

# Build every gem into the pkg directory (gem push is handled by GitHub Actions with attestations)
Rake::Task["build"].clear
desc "Build x-core, x-uploads, x-streams, x-resources, and x into the pkg directory"
task :build do
  mkdir_p "pkg"
  GEMS.each do |name, dir|
    path = Bundler::GemHelper.new(File.expand_path(dir, __dir__), name).build_gem
    mv path, "pkg" unless File.dirname(path).eql?(File.expand_path("pkg", __dir__))
  end
end

# The path of a gem that build writes into the pkg directory
def gem_path(name)
  File.expand_path("pkg/#{name}-#{version}.gem", __dir__)
end

# Bundler's install, checksum, and push tasks know only the gem of the root gemspec, x, which would install the gems
# it depends on from RubyGems rather than pkg, and push only x
%w[install install:local build:checksum release:rubygem_push].each { |name| Rake::Task[name].clear }

desc "Build and install x-core, x-uploads, x-streams, x-resources, and x into system gems"
task install: :build do
  GEMS.each_key { |name| Bundler.with_original_env { sh "gem", "install", gem_path(name) } }
end

desc "Build and install x-core, x-uploads, x-streams, x-resources, and x into system gems without network access"
task "install:local" => :build do
  GEMS.each_key { |name| Bundler.with_original_env { sh "gem", "install", gem_path(name), "--local" } }
end

desc "Check that the current branch is main, which alone is released"
task "release:guard_main" do
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  abort "Release from main, not #{branch}: the workflow that pushes the gems refuses a tag that names another commit" unless branch.eql?("main")
end

Rake::Task["release"].clear
desc "Build gems and create tag (gem push handled by CI)"
task release: %w[check_versions release:guard_main build release:guard_clean release:source_control_push]

require "rake/testtask"

# The gems with their own directory, Gemfile, test suite, and mutation config
SUBGEMS = %w[x-core x-uploads x-streams x-resources].freeze

# Run a command inside a gem's directory with that gem's own bundle, installing the bundle if needed
def in_gem(dir, *command)
  Bundler.with_unbundled_env do
    Dir.chdir(File.expand_path(dir, __dir__)) do
      sh "bundle", "install" unless system("bundle", "check", out: File::NULL)
      sh(*command)
    end
  end
end

namespace :test do
  Rake::TestTask.new(:x) do |t|
    t.description = "Run the x meta-gem tests"
    t.libs << "test"
    t.pattern = "test/**/*_test.rb"
  end

  SUBGEMS.each do |name|
    desc "Run the #{name} tests"
    task name do
      in_gem(name, "bundle", "exec", "rake", "test")
    end
  end
end

desc "Run the tests for every gem"
task test: SUBGEMS.map { |name| "test:#{name}" } + ["test:x"]

namespace :mutant do
  SUBGEMS.each do |name|
    desc "Run the #{name} mutation tests"
    task name do
      in_gem(name, "bundle", "exec", "rake", "mutant")
    end
  end
end

desc "Run the mutation tests for every gem"
task mutant: SUBGEMS.map { |name| "mutant:#{name}" }

require "standard/rake"
require "rubocop/rake_task"

RuboCop::RakeTask.new

namespace :steep do
  desc "Type check the x meta-gem"
  task :x do
    sh "bundle", "exec", "steep", "check"
  end

  SUBGEMS.each do |name|
    desc "Type check #{name}"
    task name do
      in_gem(name, "bundle", "exec", "rake", "steep")
    end
  end
end

desc "Type check every gem"
task steep: SUBGEMS.map { |name| "steep:#{name}" } + ["steep:x"]

require "yard"

# The documentation of every gem together, published at https://sferik.github.io/x-ruby/api/, written to the
# directory YARD_OUTPUT_DIR names, or doc. The .yardopts of the x gem documents the meta-gem alone, so the options of
# each gem's .yardopts are given here, and the extra files are those of the repository, as each gem names its own
# README.md and CHANGELOG.md.
#
# The .yardopts of x-resources adds --private, since the modules its classes include and extend are private constants,
# and YARD leaves a method out of the page of a class when the module that defines it is not shown; x-resources tags
# everything else that is private @api private. The other gems do not, so the query keeps what is private in them
# hidden: of all that is private, only a module tagged @api semipublic is shown.
YARD::Rake::YardocTask.new(:yard) do |t|
  t.files = ["lib/**/*.rb", "x-core/lib/**/*.rb", "x-uploads/lib/**/*.rb", "x-streams/lib/**/*.rb", "x-resources/lib/**/*.rb",
    "-", "UPGRADING.md", "CHANGELOG.md", "LICENSE.txt"]
  t.options = ["--no-yardopts", "--no-save", "--markup", "markdown", "--readme", "README.md", "--private",
    "--hide-api", "private", "--query", "object.visibility != :private || (object.type == :module && @api.text == 'semipublic')",
    "--embed-mixins", "--title", "X API Ruby gems", "--output-dir", ENV.fetch("YARD_OUTPUT_DIR", "doc")]
end

require "yardstick/rake/measurement"
require "yardstick/rake/verify"

Yardstick::Rake::Measurement.new(:yardstick_measure) do |measurement|
  measurement.output = "doc/coverage.txt"
end

namespace :yardstick do
  Yardstick::Rake::Verify.new(:x) do |verify|
    verify.threshold = 100
  end

  SUBGEMS.each do |name|
    desc "Measure #{name} documentation coverage"
    task name do
      in_gem(name, "bundle", "exec", "rake", "yardstick")
    end
  end
end

desc "Measure documentation coverage of every gem"
task yardstick: SUBGEMS.map { |name| "yardstick:#{name}" } + ["yardstick:x"]

desc "Run linters"
task lint: %i[rubocop standard]

require "yaml"

# The directory each gem keeps its signatures in, by the name of the gem
SIGNATURE_DIRS = GEMS.to_h { |name, dir| [name, File.expand_path("#{dir}/sig", __dir__)] }.freeze

# The signature files a gem ships, as its gemspec globs them
def shipped_signatures(name)
  Dir.glob("#{SIGNATURE_DIRS.fetch(name)}/*.rbs").sort
end

# The standard libraries a gem's manifest declares, which rbs collection loads with its signatures
def manifest_dependencies(name)
  YAML.load_file(File.join(SIGNATURE_DIRS.fetch(name), "manifest.yaml")).fetch("dependencies").map { |dependency| dependency.fetch("name") }
end

# The gems of this repository a gem depends on at runtime, whose signatures rbs collection installs from its gemspec
def gem_dependencies(name)
  Gem::Specification.load(File.expand_path("#{GEMS.fetch(name)}/#{name}.gemspec", __dir__)).runtime_dependencies
    .map(&:name).select { |dependency| GEMS.key?(dependency) }
end

# The signatures to load for a gem, and the libraries to load them with
#
# A gem of this repository contributes the signatures it ships, and the standard libraries its own manifest declares,
# and the gems of this repository it depends on contribute theirs, as rbs collection installs the signatures of each
# gem a gemspec depends on and reads the manifest of each.
#
# @return [Array(Array<String>, Array<String>)] the signature files and the library names
def signature_sources(name, seen = [])
  return [[], []] if seen.include?(name)

  seen << name
  gem_dependencies(name).each_with_object([shipped_signatures(name), manifest_dependencies(name)]) do |dependency, (files, libraries)|
    dependency_files, dependency_libraries = signature_sources(dependency, seen)
    files.concat(dependency_files)
    libraries.concat(dependency_libraries)
  end
end

# Check that the signatures a gem ships refer to nothing the libraries its manifest declares leave undefined
#
# Code that depends on the gem loads them through rbs collection, which reads the manifest for the libraries to load
# them with, so a library the manifest leaves out is one the signatures do not resolve without. An error that names
# the file of another library is that library's to fix, and is left to it.
#
# @return [Boolean] true if every type the signatures refer to resolves
def signatures_resolve?(name)
  files, libraries = signature_sources(name)
  arguments = files.flat_map { |file| ["-I", file] } + libraries.uniq.flat_map { |library| ["-r", library] }
  output = IO.popen(["rbs", *arguments, "validate"], err: %i[child out], &:read)
  errors = output.lines.grep(/#{Regexp.escape(SIGNATURE_DIRS.fetch(name))}/)
  errors.each { |error| warn error }
  errors.empty?
end

desc "Check that the signatures each gem ships resolve against the libraries its manifest declares"
task :signatures do
  unresolved = GEMS.each_key.reject { |name| signatures_resolve?(name) }
  abort "Declare what the signatures of #{unresolved.join(", ")} refer to in sig/manifest.yaml" unless unresolved.empty?
end

task default: %i[test lint mutant steep yardstick signatures]
