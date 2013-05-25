# This module is designed to be mixed in with your application code.
# Because of this, all instance variables are prefixed with an underscore.
# The hope is to minimize the chances of conflicts.
# Long term my goal is to move all of these variables into an ActorState object.

module Tribe
  module Actable
    include Workers::Helpers

    private

    def init_actable(options = {})
      # Symbols aren't GCed in JRuby so force string names.
      if options[:name] && !options[:name].is_a?(String)
        raise Tribe::ActorNameError.new('Name must be a string.')
      end

      @_logger = Workers::LogProxy.new(options[:logger])
      @_dedicated = options[:dedicated] || false
      @_mailbox = options[:mailbox] || Tribe::Mailbox.new
      @_registry = options[:registry] || Tribe.registry
      @_scheduler = options[:scheduler] || Workers.scheduler
      @_timers = Tribe::SafeSet.new
      @_name = options[:name]
      @_pool = @_dedicated ? Workers::Pool.new(:size => 1) : (options[:pool] || Workers.pool)
      @_alive = true
      @_futures = Tribe::SafeSet.new

      @_registry.register(self)
    end

    public

    def enqueue(command, data = nil)
      return false unless alive?

      @_mailbox.push(Workers::Event.new(command, data)) do
        @_pool.perform { process_events }
      end

      return true
    end

    def enqueue_future(command, data = nil)
      future = Tribe::Future.new
      @_futures.add(future)

      perform do
        begin
          result = result = process_event(Workers::Event.new(command, data))
          future.result = result
        rescue Exception => e
          future.result = e
          raise
        ensure
          @_futures.delete(future)
        end
      end

      return future
    end

    def alive?
      @_mailbox.synchronize { return @_alive }
    end

    def name
      return @_name
    end

    def identifier
      return @_name ? "#{object_id}:#{@_name}" : object_id
    end

    def shutdown
      return enqueue(:shutdown)
    end

    def perform(&block)
      return enqueue(:perform, block)
    end

    private

    def registry
      return @_registry
    end

    def pool
      return @_pool
    end

    def logger
      return @_logger
    end

    def process_events
      while (event = @_mailbox.shift)
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
      cleanup(e)
      exception_handler(e)
    ensure
      @_mailbox.release do
        @_pool.perform { process_events if @_alive }
      end

      return nil
    end

    def cleanup(e = nil)
      @_pool.shutdown if @_dedicated
      @_mailbox.synchronize { @_alive = false }
      @_registry.unregister(self)
      @_timers.each { |t| t.cancel }
      @_futures.each { |f| f.result = e || Tribe::ActorShutdownError.new }

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
      return nil
    end

    def perform_handler(event)
      event.data.call

      return nil
    end

    def timer(delay, command, data = nil)
      timer = Workers::Timer.new(delay, :scheduler => @_scheduler) do
        @_timers.delete(timer)
        enqueue(command, data)
      end

      @_timers.add(timer)

      return timer
    end

    def periodic_timer(delay, command, data = nil)
      timer = Workers::PeriodicTimer.new(delay, :scheduler => @_scheduler) do
        enqueue(command, data)
        unless alive?
          @_timers.delete(timer)
          timer.cancel
        end
      end

      @_timers.add(timer)

      return timer
    end
  end
end
