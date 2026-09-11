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

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end

require "standard/rake"
require "rubocop/rake_task"

RuboCop::RakeTask.new

require "steep/rake_task"

Steep::RakeTask.new(:steep)

require "mutant"

desc "Run mutation tests"
task :mutant do
  sh "bundle exec mutant run"
end

require "yard"

YARD::Rake::YardocTask.new(:yard) do |t|
  t.files = ["lib/**/*.rb", "x-core/lib/**/*.rb", "x-objects/lib/**/*.rb"]
  t.options = ["--no-private"]
end

require "yardstick/rake/measurement"
require "yardstick/rake/verify"

Yardstick::Rake::Measurement.new(:yardstick_measure) do |measurement|
  measurement.path = "{lib,x-core/lib,x-objects/lib}/**/*.rb"
  measurement.output = "doc/coverage.txt"
end

Yardstick::Rake::Verify.new(:yardstick) do |verify|
  verify.path = "{lib,x-core/lib,x-objects/lib}/**/*.rb"
  verify.threshold = 100
end

desc "Run linters"
task lint: %i[rubocop standard]

task default: %i[test lint mutant steep yardstick]
