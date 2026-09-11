require "bundler/gem_tasks"

# The gems in this repository, in dependency order, released in lockstep
GEMS = {"x-core" => "x-core", "x-objects" => "x-objects", "x" => "."}.freeze

# Build every gem into the pkg directory (gem push is handled by GitHub Actions with attestations)
Rake::Task["build"].clear
desc "Build x-core, x-objects, and x into the pkg directory"
task :build do
  mkdir_p "pkg"
  GEMS.each do |name, dir|
    path = Bundler::GemHelper.new(File.expand_path(dir, __dir__), name).build_gem
    mv path, "pkg" unless File.dirname(path).eql?(File.expand_path("pkg", __dir__))
  end
end

Rake::Task["release"].clear
desc "Build gems and create tag (gem push handled by CI)"
task release: %w[build release:guard_clean release:source_control_push]

require "rake/testtask"

# The gems with their own directory, Gemfile, test suite, and mutation config
SUBGEMS = %w[x-core x-objects].freeze

# Run a command inside a gem's directory with that gem's own bundle
def in_gem(dir, *command)
  Bundler.with_unbundled_env do
    Dir.chdir(File.expand_path(dir, __dir__)) { sh(*command) }
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
  t.files = ["lib/**/*.rb", "x-core/lib/**/*.rb", "x-objects/lib/**/*.rb"]
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
