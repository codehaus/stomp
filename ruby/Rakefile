require 'rubygems'
require 'rake'
require 'rake/testtask' 
require 'rake/clean'
require 'rake/gempackagetask'

Gem::manage_gems

task :default => ['test']

spec = Gem::Specification.new do |s|
  s.name = "stomp"
  s.version = "1.0.0"
  s.author = "Brian McCallister"
  s.email = "brian@skife.org"
  s.homepage = "http://stomp.codehaus.org/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby client xfor the Stomp messaging protocol"
  s.files =  FileList["lib/stomp.rb"]
  s.require_path = "lib"
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end
