module Tribe
  class Scheduler
    FREQUENCY = 1000 # Hz.

    def initialize(options = {})
      @frequency = options[:frequency] || FREQUENCY
      @run = true
      @timers = SortedSet.new
      @messages = Queue.new
      @thread = Thread.new { main }
    end

    def shutdown
      @messages.push([ :shutdown ])

      @thread.join
    end

    def schedule(timer)
      @messages.push([ :schedule, timer ])

      true
    end

    def unschedule(timer)
      @messages.push([ :unschedule, timer ])

      true
    end

    private
    def main
      sleep_val = 60.0 / @frequency

      while @run
        sleep(sleep_val)
        process_commands
        fire_timers
      end
    end

    def process_commands
      @messages.length.times do
        message = @messages.pop

        case message[0]
        when :schedule
          @timers.add(message[1])
        when :unschedule
          @timers.delete(message[1])
        when :shutdown
          @run = false
        else
          raise("Invalid command: #{message[0]}")
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
