#   Copyright 2005-2006 Brian McCallister
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

require 'rubygems'
require 'rake'
require 'rake/testtask' 
require 'rake/clean'
require 'rake/gempackagetask'

Gem::manage_gems

task :default => ['test']

spec = Gem::Specification.new do |s|
  s.name = "stomp"
  s.version = "1.0.2"
  s.author = "Brian McCallister"
  s.email = "brianm@apache.org"
  s.homepage = "http://stomp.codehaus.org/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby client for the Stomp messaging protocol"
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
