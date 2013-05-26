module Tribe
  module Actable
    include Workers::Helpers

    private

    def init_actable(options = {})
      # Symbols aren't GCed in JRuby so force string names.
      if options[:name] && !options[:name].is_a?(String)
        raise Tribe::ActorNameError.new('Name must be a string.')
      end

      @logger = Workers::LogProxy.new(options[:logger])
      @_as = Tribe::ActorState.new
      @_as.dedicated = options[:dedicated] || false
      @_as.mailbox = options[:mailbox] || Tribe::Mailbox.new
      @_as.registry = options[:registry] || Tribe.registry
      @_as.scheduler = options[:scheduler] || Workers.scheduler
      @_as.timers = Tribe::SafeSet.new
      @_as.name = options[:name]
      @_as.pool = @_as.dedicated ? Workers::Pool.new(:size => 1) : (options[:pool] || Workers.pool)
      @_as.alive = true
      @_as.futures = Tribe::SafeSet.new

      @_as.registry.register(self)
    end

    public

    def enqueue(command, data = nil)
      return false unless alive?

      @_as.mailbox.push(Workers::Event.new(command, data)) do
        @_as.pool.perform { process_events }
      end

      return true
    end

    def enqueue_future(command, data = nil)
      future = Tribe::Future.new
      @_as.futures.add(future)

      perform do
        begin
          result = result = process_event(Workers::Event.new(command, data))
          future.result = result
        rescue Exception => e
          future.result = e
          raise
        ensure
          @_as.futures.delete(future)
        end
      end

      return future
    end

    def alive?
      @_as.mailbox.synchronize { return @_as.alive }
    end

    def name
      return @_as.name
    end

    def identifier
      return @_as.name ? "#{object_id}:#{@_as.name}" : object_id
    end

    def shutdown
      return enqueue(:shutdown)
    end

    def perform(&block)
      return enqueue(:perform, block)
    end

    private

    def registry
      return @_as.registry
    end

    def pool
      return @_as.pool
    end

    def process_events
      while (event = @_as.mailbox.shift)
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
      @_as.mailbox.release do
        @_as.pool.perform { process_events if @_as.alive }
      end

      return nil
    end

    def cleanup(e = nil)
      @_as.pool.shutdown if @_as.dedicated
      @_as.mailbox.synchronize { @_as.alive = false }
      @_as.registry.unregister(self)
      @_as.timers.each { |t| t.cancel }
      @_as.futures.each { |f| f.result = e || Tribe::ActorShutdownError.new }

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
      timer = Workers::Timer.new(delay, :scheduler => @_as.scheduler) do
        @_as.timers.delete(timer)
        enqueue(command, data)
      end

      @_as.timers.add(timer)

      return timer
    end

    def periodic_timer(delay, command, data = nil)
      timer = Workers::PeriodicTimer.new(delay, :scheduler => @_as.scheduler) do
        enqueue(command, data)
        unless alive?
          @_as.timers.delete(timer)
          timer.cancel
        end
      end

      @_as.timers.add(timer)

      return timer
    end
  end
end
