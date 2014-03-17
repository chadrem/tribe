module Tribe
  module Benchmark
    module Throughput
      MAX_INCR    = 100000
      ACTOR_COUNT = 100000
      COUNTERS    = 20

      def self.run
        ACTOR_COUNT.times do |i|
          actor = Tribe.registry["actor_#{i}"]
          actor.shutdown! if actor
        end

        $start_time = Time.now.utc
        $finished = 0
        $lock = Mutex.new

        ACTOR_COUNT.times do |i|
          MyActor.new(:name => "actor_#{i}")
        end

        COUNTERS.times do |i|
          Tribe.registry["actor_#{rand(ACTOR_COUNT)}"].deliver_message!(:do_stuff, MyData.new("data_#{i}"))
        end

        $lock.synchronize do
          puts 'Please wait...'
        end
      end

      def self.stop
      end

      class MyData
        def initialize(name)
          @name = name
          @counter = 0
          @start_time = Time.now
        end

        def increment
          @counter += 1

          if @counter >= MAX_INCR
            $lock.synchronize do
              $finished += 1

              if $finished == COUNTERS
                puts "\nFinished! Rate=#{(COUNTERS * MAX_INCR).to_f / (Time.now.utc - $start_time).to_f } msgs/sec\n"
              end
            end

            return false
          end

          return true
        end
      end

      class MyActor < Tribe::Actor
        private
        def on_do_stuff(event)
          if event.data.increment
            Tribe.registry["actor_#{rand(ACTOR_COUNT)}"].deliver_message!(:do_stuff, event.data)
          end
        end

        def exception_handler(e)
          puts concat_e("MyActor (#{identifier}) died.", e)
        end
      end
    end
  end
end
