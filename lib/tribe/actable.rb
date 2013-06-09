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
      @_as.pool = @_as.dedicated ? Workers::Pool.new(:size => 1) : (options[:pool] || Workers.pool)
      @_as.mailbox = Tribe::Mailbox.new(@_as.pool)
      @_as.registry = options[:registry] || Tribe.registry
      @_as.scheduler = options[:scheduler]
      @_as.name = options[:name]
      @_as.parent = options[:parent]

      @_as.registry.register(self)
    end

    #
    # Thread safe public methods.
    # Notes: These are the methods that actors use to communicate with each other.
    #        Actors should avoid sharing mutable state in order to remain thread safe.
    #        Methods with a ! are designed for asynchronous communication.
    #

    public

    def _parent
      return @_as.parent
    end

    def _children
      return @_as.children
    end

    def _exception
      return @_as.exception
    end

    def event!(event)
      push_event(event)

      return nil
    end

    def message!(command, data = nil, source = nil)
      event = Tribe::Event.new(command, data, source)

      push_event(event)

      return nil
    end

    def future!(command, data = nil, source = nil)
      event = Tribe::Event.new(command, data, source)
      event.future = future = Tribe::Future.new

      push_event(event)

      return future
    end

    def shutdown!
      return message!(:shutdown)
    end

    def perform!(&block)
      return message!(:perform, block)
    end

    def alive?
      @_as.mailbox.alive?
    end

    def name
      return @_as.name
    end

    def identifier
      return @_as.name ? "#{object_id}:#{@_as.name}" : object_id
    end

    def link(child)
    end

    def unlink(child)
    end

    #
    # Private event handlers.
    # Notes: These methods are designed to be overriden (make sure you call super).
    #

    private

    def event_handler(event)
      result = nil
      @_as.active_event = event

      begin
        result = send("on_#{event.command}", event)
      rescue Exception => e
        result = e
        raise
      ensure
        if event.future && @_as.active_event
          event.future.result = result
        end
        @_as.active_event = nil
      end

      return nil
    end

    def exception_handler(exception)
      if @_as.parent
        @_as.parent.perform! do
          e = Tribe::ActorChildDied.new
          e.data = exception
          raise e
        end
      end

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
      @_as.exception = exception
      @_as.pool.shutdown if @_as.dedicated
      @_as.mailbox.kill
      @_as.registry.unregister(self)
      @_as.timers.each { |t| t.cancel } if @_as.timers

      if @_as.children
        @_as.children.each { |c| c.shutdown! }
        @_as.children.clear
      end

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

    def forward!(dest)
      dest.event!(@_as.active_event)
      @_as.active_event = nil

      return nil
    end

    def spawn(klass, options = {})
      options[:parent] = self

      @_as.children ||= []
      @_as.children << (actor = klass.new(options))

      return actor
    end

    def push_event(event)
      @_as.mailbox.push(event) do
        process_events
      end
    end

    def process_events
      while (event = @_as.mailbox.obtain_and_shift)
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
        process_events
      end

      return nil
    end
  end
end
