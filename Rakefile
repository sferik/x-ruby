require "bundler/gem_tasks"

# Override release task to skip gem push (handled by GitHub Actions with attestations)
Rake::Task["release"].clear
desc "Build gem and create tag (gem push handled by CI)"
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
  t.files = ["lib/**/*.rb"]
  t.options = ["--no-private"]
end

require "yardstick/rake/measurement"
require "yardstick/rake/verify"

Yardstick::Rake::Measurement.new(:yardstick_measure) do |measurement|
  measurement.output = "doc/coverage.txt"
end

Yardstick::Rake::Verify.new(:yardstick) do |verify|
  verify.threshold = 100
end

desc "Run linters"
task lint: %i[rubocop standard]

task default: %i[test lint mutant steep yardstick]
