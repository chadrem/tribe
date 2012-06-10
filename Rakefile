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

#
# TODO: Temporary benchmarking/demo code.
#

require 'benchmark'

$demo_queue = Queue.new

DEMO_ACTOR_COUNT = 100
DEMO_MSG_COUNT = 3000

class MyActor < Tribe::Actor

  def pre_init
    reset_count
  end

  def increment
    @count += 1

    if @count >= DEMO_MSG_COUNT
      puts "#{@name} done."
      $demo_queue.push(@name)
    end
  end

  def reset_count
    @count = 0
  end

  def go(friend_name)
    friend = Tribe.registry[friend_name]

    DEMO_MSG_COUNT.times do
      friend.increment!
    end
  end
end

def tribe_demo
  actors = []

  puts 'Create actors...'
  (0...DEMO_ACTOR_COUNT).each do |i|
    name = i.to_s
    actor = Tribe.registry[name] || MyActor.new(:name => name)
    actors.push(actor)
    puts name
  end

  puts 'Resetting...'
  actors.each do |actor|
    actor.reset_count!
  end

  puts 'Go...'
  actors.each do |actor|
    friend = actor.name.to_i
    friend += 1
    friend = 0 if friend == DEMO_ACTOR_COUNT
    friend = friend.to_s

    puts "pair: #{actor.name}, #{friend}"
    actor.go!(friend)
  end

  puts 'Benchmark...'
  result = Benchmark.realtime do
    DEMO_ACTOR_COUNT.times do
      $demo_queue.pop
    end
  end

  puts result

  nil
end
