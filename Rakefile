require "bundler/gem_tasks"

# Override release task to skip gem push (handled by GitHub Actions with attestations)
Rake::Task["release"].clear
desc "Build gem and create tag (gem push handled by CI)"
task release: %w[build release:guard_clean release:source_control_push]
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.options = "--pride"
  t.test_files = FileList["test/**/*_test.rb"]
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

desc "Run linters"
task lint: %i[rubocop standard]

task default: %i[test lint mutant steep]
