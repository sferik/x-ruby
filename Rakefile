require "bundler/gem_tasks"
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

desc "Run mutant"
task :mutant do
  system(*%w[bundle exec mutant run]) or raise "Mutant task failed"
end

desc "Run linters"
task lint: %i[rubocop standard]

task default: %i[test lint mutant steep]
