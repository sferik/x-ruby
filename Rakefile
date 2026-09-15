require "bundler/gem_tasks"

# The gems in this repository, in dependency order, released in lockstep
GEMS = {"x-core" => "x-core", "x-uploader" => "x-uploader", "x-objects" => "x-objects", "x" => "."}.freeze

# The one file that holds the version, which every gemspec reads
VERSION_FILE = File.expand_path("VERSION", __dir__)

# The files that hold each gem's runtime version constant, written from VERSION_FILE
VERSION_CONSTANT_FILES = %w[lib/x/version.rb x-core/lib/x/core/version.rb x-uploader/lib/x/uploader/version.rb
  x-objects/lib/x/objects/version.rb].map { |path| File.expand_path(path, __dir__) }.freeze

# The version in VERSION_FILE
def version
  File.read(VERSION_FILE).strip
end

# The version a version.rb file holds
def version_in(file)
  File.read(file)[/Gem::Version\.create\("([^"]+)"\)/, 1]
end

desc "Write the version in VERSION into each gem's version.rb"
task :update_versions do
  VERSION_CONSTANT_FILES.each do |file|
    File.write(file, File.read(file).sub(/Gem::Version\.create\("[^"]+"\)/, %(Gem::Version.create("#{version}"))))
  end
end

desc "Check that each gem's version.rb holds the version in VERSION"
task :check_versions do
  stale = VERSION_CONSTANT_FILES.reject { |file| version_in(file).eql?(version) }
  abort "Run `rake update_versions`: #{stale.join(", ")} do not hold #{version}" unless stale.empty?
end

# Build every gem into the pkg directory (gem push is handled by GitHub Actions with attestations)
Rake::Task["build"].clear
desc "Build x-core, x-uploader, x-objects, and x into the pkg directory"
task :build do
  mkdir_p "pkg"
  GEMS.each do |name, dir|
    path = Bundler::GemHelper.new(File.expand_path(dir, __dir__), name).build_gem
    mv path, "pkg" unless File.dirname(path).eql?(File.expand_path("pkg", __dir__))
  end
end

Rake::Task["release"].clear
desc "Build gems and create tag (gem push handled by CI)"
task release: %w[check_versions build release:guard_clean release:source_control_push]

require "rake/testtask"

# The gems with their own directory, Gemfile, test suite, and mutation config
SUBGEMS = %w[x-core x-uploader x-objects].freeze

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

YARD::Rake::YardocTask.new(:yard) do |t|
  t.files = ["lib/**/*.rb", "x-core/lib/**/*.rb", "x-uploader/lib/**/*.rb", "x-objects/lib/**/*.rb"]
  t.options = ["--no-private"]
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

task default: %i[test lint mutant steep yardstick]
