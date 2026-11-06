require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib" << "test"
  t.pattern = "test/**/*_test.rb"
end

task default: :test

desc "Build the static docs site into _site"
task :build do
  ruby "bin/build"
end
