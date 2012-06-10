module Tribe
  class Timer
    attr_reader :fire_at
    attr_reader :repeat

    def initialize(seconds, options = {}, &block)
      @seconds = seconds.to_f
      @callback = block
      @scheduler = options[:scheduler] || Tribe.scheduler
      @repeat = options[:repeat] || false

      schedule
    end

    def cancel
      @scheduler.unschedule(self)
    end

    def <=>(timer)
      if self.object_id == timer.object_id
        return 0
      else
        return self.fire_at <=> timer.fire_at
      end
    end

    private
    def fire?(current_time = nil)
      current_time ||= now

      now >= @fire_at
    end

    def fire
      @callback.call
    rescue Exception => e
      puts "Timer caught exception: #{e.message}\n#{e.backtrace.join("\n")}"
    ensure
      schedule if @repeat
    end

    def now
      Time.now.to_f
    end

    def schedule
      @fire_at = now + @seconds
      @scheduler.schedule(self)
    end
  end
end
