module Tribe
  module Actable
    include Workers::Helpers

    def init_actable(options = {})
      @logger = Workers::LogProxy.new(options[:logger])
      @dedicated = options[:dedicated] || false
      @mailbox = options[:mailbox] || Tribe::Mailbox.new
      @registry = options[:registry] || Tribe.registry
      @scheduler = options[:scheduler] || Workers.scheduler
      @timers = Tribe::SafeSet.new
      @name = options[:name]
      @pool = @dedicated ? Workers::Pool.new(:size => 1) : (options[:pool] || Workers.pool)
      @alive = true

      @registry.register(self)
    end

    def enqueue(command, data = nil)
      return false unless alive?

      @mailbox.push(Workers::Event.new(command, data)) do
        @pool.perform { process_events }
      end

      return true
    end

    def enqueue_future(command, data = nil)
      future = Tribe::Future.new

      perform do
        begin
          result = result = process_event(Workers::Event.new(command, data))
          future.result = result
        rescue Exception => e
          future.result = e
          raise
        end
      end

      return future
    end

    def alive?
      @mailbox.synchronize { return @alive }
    end

    def name
      return @name
    end

    def identifier
      return @name ? "#{object_id}:#{@name}" : object_id
    end

    def shutdown
      return enqueue(:shutdown)
    end

    def perform(&block)
      return enqueue(:perform, block)
    end

    private

    def process_events
      while (event = @mailbox.shift)
        case event.command
        when :shutdown
          cleanup
          shutdown_handler(event)
        when :perform
          perform_handler(event)
        else
          process_event(event)
        end
      end

    rescue Exception => e
      cleanup
      exception_handler(e)
    ensure
      @mailbox.release do
        @pool.perform { process_events if @alive }
      end

      return nil
    end

    def cleanup
      @pool.shutdown if @dedicated
      @mailbox.synchronize { @alive = false }
      @registry.unregister(self)

      return nil
    end

    # Override and call super as necessary.
    # Note that the return value is used as the result of a future.
    def process_event(event)
      return send("on_#{event.command}", event)
    end

    # Override and call super as necessary.
    def exception_handler(e)
      return nil
    end

    # Override and call super as necessary.
    def shutdown_handler(event)
      shutdown_timers

      return nil
    end

    def shutdown_timers
      @timers.each do |timer|
        timer.cancel
      end

      return nil
    end

    def perform_handler(event)
      event.data.call

      return nil
    end

    def timer(delay, command, data = nil)
      timer = Workers::Timer.new(delay, :scheduler => @scheduler) do
        @timers.delete(timer)
        enqueue(command, data)
      end

      @timers.add(timer)

      return timer
    end

    def periodic_timer(delay, command, data = nil)
      timer = Workers::PeriodicTimer.new(delay, :scheduler => @scheduler) do
        enqueue(command, data)
        unless alive?
          @timers.delete(timer)
          timer.cancel
        end
      end

      @timers.add(timer)

      return timer
    end

    def registry
      return @registry
    end
  end
end
