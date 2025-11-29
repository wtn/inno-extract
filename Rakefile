require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

task default: :test

desc "Remove downloaded .exe files and output from tmp/"
task :clean do
  FileUtils.rm_f(Dir.glob("tmp/*.exe"))
  FileUtils.rm_rf("tmp/output")
end
