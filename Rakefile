#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'benchmark'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts(e.message)
  $stderr.puts("Run `bundle install` to install missing gems")
  exit e.status_code
end

task :environment do
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
  require 'tribe'
end

desc 'Start an IRB console with offier loaded'
task :console => :environment do
  require 'irb'

  ARGV.clear

  IRB.start
end

desc 'Demo mode (temporary)'
task :demo => :environment do
  $demo_queue = Queue.new
  $demo_mutex = Mutex.new

  def locked_puts(msg)
    $demo_mutex.synchronize { puts msg }
  end

  DEMO_ACTOR_COUNT = 100
  DEMO_MSG_COUNT = 3000

  class MyActor < Tribe::Actor

    def pre_init
      reset_count
    end 

    def increment
      @count += 1

      if @count >= DEMO_MSG_COUNT
        locked_puts("#{@name} done.")
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

    locked_puts('Create actors...')
    (0...DEMO_ACTOR_COUNT).each do |i|
      name = i.to_s
      actor = Tribe.registry[name] || MyActor.new(:name => name)
      actors.push(actor)
      locked_puts(name)
    end

    locked_puts('Resetting...')
    actors.each do |actor|
      actor.reset_count!
    end

    locked_puts('Go...')
    actors.each do |actor|
      friend = actor.name.to_i
      friend += 1
      friend = 0 if friend == DEMO_ACTOR_COUNT
      friend = friend.to_s

      locked_puts("pair: #{actor.name}, #{friend}")
      actor.go!(friend)
    end

    locked_puts('Benchmark...')
    result = Benchmark.realtime do
      DEMO_ACTOR_COUNT.times do
        $demo_queue.pop
      end
    end

    nil
  end

  tribe_demo
end

