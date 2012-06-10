# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "tribe"
  gem.homepage = "http://github.com/chadrem/tribe"
  gem.license = "MIT"
  gem.summary = %Q{Actor Model for Ruby}
  gem.description = %Q{Actor Model for Ruby.  Can support millions of actors (limited by memory). Currently experimental and not recommended for production.}
  gem.email = "chad@remesch.com"
  gem.authors = ["Chad Remesch"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "tribe #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'debugger'
rescue LoadError
end

require 'tribe'

class MyActor < Tribe::Actor
  def pre_init
    @count = 0
  end

  def increment
    @count += 1
    puts "#{@name}=#{@count}" if @count >= 50000
  end

  def go(friend_name)
    friend = Tribe.registry[friend_name]

    50000.times do
      friend.increment!
    end
  end
end

def tribe_demo
  a1 = Tribe.registry['a1'] || MyActor.new(:name => 'a1')
  a2 = Tribe.registry['a2'] || MyActor.new(:name => 'a2')
  a3 = Tribe.registry['a3'] || MyActor.new(:name => 'a3')
  a4 = Tribe.registry['a4'] || MyActor.new(:name => 'a4')
  a5 = Tribe.registry['a5'] || MyActor.new(:name => 'a5')
  a6 = Tribe.registry['a6'] || MyActor.new(:name => 'a6')

  a1.go!('a2')
  a2.go!('a1')
  a3.go!('a4')
  a4.go!('a3')
  a5.go!('a6')
  a6.go!('a5')
end
