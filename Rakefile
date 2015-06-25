require "bundler/gem_tasks"

desc 'Start an IRB console with Workers loaded'
task :console do
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))

  require 'tribe'
  require 'tribe/benchmark'
  require 'irb'

  ARGV.clear

  IRB.start
end

def foo
  t = Thread.new do
    i = 0
    while i < 100 do
      1000.times do
        t = Tribe.root.spawn(Tribe::Actor)
        t.shutdown!
        t = nil
      end
      puts Time.now
      i += 1
    end
  end
  t.join
end