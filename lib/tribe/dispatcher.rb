module Tribe
  class Dispatcher
    FREQUENCY = 1000 # Hz.

    def initialize(options = {})
      @frequency = options[:frequency] || FREQUENCY
      @pool = ThreadPool.new(:count => options[:count])
      @actors = Set.new
      @lock = Mutex.new
      @run = true
      @thread = Thread.new { thread_main }
    end

    def shutdown
      @pool.shutdown
      @lock.synchronize { @run = false }
      @thread.join
    end

    private
    def schedule(actor)
      @lock.synchronize do
        @actors.add(actor)
      end
    end

    def thread_main
      sleep_val = 60.0 / @frequency
      actors_tmp = nil

      while true
        sleep(sleep_val)

        @lock.synchronize do
          return unless @run

          actors_tmp = @actors
          @actors = Set.new
        end

        actors_tmp.each do |actor|
          @pool.dispatch do
            actor.send(:process)
          end
        end
      end
    end
  end
end
