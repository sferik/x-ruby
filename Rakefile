require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
end

require "standard/rake"
require "rubocop/rake_task"

RuboCop::RakeTask.new

require "steep"
require "steep/cli"

desc "Type check with Steep"
task :steep do
  Steep::CLI.new(argv: ["check"], stdout: $stdout, stderr: $stderr, stdin: $stdin).run
end

task default: %i[test rubocop standard steep]
