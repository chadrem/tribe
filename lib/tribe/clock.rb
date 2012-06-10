module Tribe
  class Clock < Tribe::Singleton
    FREQUENCY = 100 # Hz.

    def initialize(options = {})
      @frequency = options[:frequency] || FREQUENCY
      @run = true
      @timers = SortedSet.new
      @messages = Queue.new
      @thread = Thread.new { main }
    end

    def shutdown
      message = { :command => :shutdown }
      @messages.push(message)

      @thread.join
    end

    def schedule(timer)
      message = { :command => :schedule, :timer => timer }
      @messages.push(message)

      true
    end

    def unschedule(timer)
      message = { :command => :unschedule, :timer => timer }
      @messages.push(message)

      true
    end

    private
    def main
      sleep_val = 1.0 / @frequency

      while @run
        sleep(sleep_val)
        process_commands
        fire_timers
      end
    end

    def process_commands
      @messages.length.times do
        message = @messages.pop

        case message[:command]
        when :schedule
          @timers.add(message[:timer])
        when :unschedule
          @timers.delete(message[:timer])
        when :shutdown
          @run = false
        else
          raise("Invalid command: #{message[:command]}")
        end
      end
    end

    def fire_timers
      count = 0

      while true
        return 0 if @timers.empty?

        if (timer = @timers.first).send(:fire?)
          @timers.delete(timer)
          timer.send(:fire)
          count += 1
        else
          return count
        end
      end
    end
  end
end
