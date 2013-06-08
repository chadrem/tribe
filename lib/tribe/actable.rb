module Tribe
  module Actable
    include Workers::Helpers

    #
    # Initialization method.
    # Notes: Call this in your constructor.
    #

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
      @_as.scheduler = options[:scheduler]
      @_as.name = options[:name]
      @_as.pool = @_as.dedicated ? Workers::Pool.new(:size => 1) : (options[:pool] || Workers.pool)
      @_as.alive = true

      @_as.registry.register(self)
    end

    #
    # Thread safe public methods.
    # Notes: These are the methods that actors use to communicate with each other.
    #        Actors should avoid sharing mutable state in order to remain thread safe.
    #        Methods with a ! are designed for asynchronous communication.
    #

    public

    def message!(command, data = nil)
      return forward!(Workers::Event.new(command, data))
    end

    def forward!(event)
      return nil unless alive?

      @_as.mailbox.push(event) do
        @_as.pool.perform { process_events }
      end

      return nil
    end

    def future!(command, data = nil)
      @_as.futures ||= Tribe::SafeSet.new # Lazy instantiation for performance.

      future = Tribe::Future.new
      @_as.futures.add(future)

      perform! do
        begin
          result = event_handler(Workers::Event.new(command, data))
          future.result = result
        rescue Exception => exception
          future.result = exception
          raise
        ensure
          @_as.futures.delete(future)
        end
      end

      return future
    end

    def shutdown!
      return message!(:shutdown)
    end

    def perform!(&block)
      return message!(:perform, block)
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

    #
    # Private event handlers.
    # Notes: These methods are designed to be overriden (make sure you call super).
    #

    private

    # The return value is used as the result of a future.
    def event_handler(event)
      return send("on_#{event.command}", event)
    end

    def exception_handler(exception)
      return nil
    end

    def shutdown_handler(event)
      return nil
    end

    def perform_handler(event)
      event.data.call

      return nil
    end

    def cleanup_handler(exception = nil)
      @_as.pool.shutdown if @_as.dedicated
      @_as.mailbox.synchronize { @_as.alive = false }
      @_as.registry.unregister(self)
      @_as.timers.each { |t| t.cancel } if @_as.timers
      @_as.futures.each { |f| f.result = exception || Tribe::ActorShutdownError.new } if @_as.futures

      return nil
    end

    #
    # Private API methods.
    # Notes: Use these methods internally in your actor.
    #

    private

    def registry
      return @_as.registry
    end

    def pool
      return @_as.pool
    end

    def timer(delay, command, data = nil)
      # Lazy instantiation for performance.
      @_as.scheduler ||= Workers.scheduler
      @_as.timers ||= Tribe::SafeSet.new

      timer = Workers::Timer.new(delay, :scheduler => @_as.scheduler) do
        @_as.timers.delete(timer)
        message!(command, data)
      end

      @_as.timers.add(timer)

      return timer
    end

    def periodic_timer(delay, command, data = nil)
      # Lazy instantiation for performance.
      @_as.scheduler ||= Workers.scheduler
      @_as.timers ||= Tribe::SafeSet.new

      timer = Workers::PeriodicTimer.new(delay, :scheduler => @_as.scheduler) do
        message!(command, data)
        unless alive?
          @_as.timers.delete(timer)
          timer.cancel
        end
      end

      @_as.timers.add(timer)

      return timer
    end

    #
    # Private internal methods.
    # Notes: These are used by the actor system and you should never call them directly.
    #

    def process_events
      while (event = @_as.mailbox.shift)
        case event.command
        when :shutdown
          cleanup_handler
          shutdown_handler(event)
        when :perform
          perform_handler(event)
        else
          event_handler(event)
        end
      end

    rescue Exception => exception
      cleanup_handler(exception)
      exception_handler(exception)
    ensure
      @_as.mailbox.release do
        @_as.pool.perform { process_events if @_as.alive }
      end

      return nil
    end
  end
end
