require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test' # 'test' is the name of the directory with the tests in
end

Rake::TestTask.new do |t|
  t.name = :tabu
  t.libs << 'test'
  t.test_files = ['test/test_tabu.rb']
end

Rake::TestTask.new do |t|
  t.name = :sweep
  t.libs << 'test'
  t.test_files = ['test/test_parametersweep.rb']
end

desc "Run tests"
task :default => :test