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
      @_as.children = Tribe::SafeSet.new
      @_as.supervisees = Tribe::SafeSet.new

      @_as.registry.register(self)
    end

    #
    # Thread safe public methods.
    # Notes: These are the methods that actors use to communicate with each other.
    #        Actors should avoid sharing mutable state in order to remain thread safe.
    #        Methods with a ! are designed for asynchronous communication.
    #

    public

    def deliver_event!(event)
      @_as.mailbox.push(event) do
        process_events
      end

      return nil
    end

    def direct_message!(command, data = nil, src = nil)
      deliver_event!(Tribe::Event.new(command, data, src))

      return nil
    end

    def message!(dest, command, data = nil)
      event = Tribe::Event.new(command, data, self)

      dest.deliver_event!(event)

      return nil
    end

    def future!(dest, command, data = nil)
      event = Tribe::Event.new(command, data, self)
      event.future = future = Tribe::Future.new(self)

      dest.deliver_event!(event)

      return future
    end

    def shutdown!
      return direct_message!(:_shutdown)
    end

    def perform!(&block)
      return direct_message!(:_perform, block)
    end

    def spawn(klass, actor_options = {}, spawn_options = {})
      actor_options[:parent] = self

      child = nil

      if spawn_options[:no_raise_on_failure]
        begin
          child = klass.new(actor_options)
        rescue Exception => e
          return false
        end
      else
        child = klass.new(actor_options)
      end

      @_as.children.add(child)

      if spawn_options[:supervise]
        @_as.supervisees.add(child)
      end

      return child
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

    def exception
      return @_as.exception
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
        @_as.parent.direct_message!(:_child_died, [self, exception])
      end

      @_as.children.each { |c| c.direct_message!(:_parent_died, [self, exception]) }
      @_as.children.clear
      @_as.supervisees.clear

      return nil
    end

    def shutdown_handler(event)
      if @_as.parent
        @_as.parent.direct_message!(:_child_shutdown, self)
      end

      @_as.children.each { |c| c.shutdown! }
      @_as.children.clear
      @_as.supervisees.clear

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

      return nil
    end

    def child_died_handler(child, exception)
      @_as.children.delete(child)
      supervising = !!@_as.supervisees.delete?(child)

      if !supervising
        raise Tribe::ActorChildDied.new("#{child.identifier} died.")
      end
    end

    def child_shutdown_handler(child)
      @_as.children.delete(child)
      @_as.supervisees.delete(child)
    end

    def parent_died_handler(parent, exception)
      raise Tribe::ActorParentDied.new("#{parent.identifier} died.")
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
        direct_message!(command, data)
      end

      @_as.timers.add(timer)

      return timer
    end

    def periodic_timer(delay, command, data = nil)
      # Lazy instantiation for performance.
      @_as.scheduler ||= Workers.scheduler
      @_as.timers ||= Tribe::SafeSet.new

      timer = Workers::PeriodicTimer.new(delay, :scheduler => @_as.scheduler) do
        direct_message!(command, data)
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
      dest.deliver_event!(@_as.active_event)
      @_as.active_event = nil

      return nil
    end

    # All system commands are prefixed with an underscore.
    def process_events
      while (event = @_as.mailbox.obtain_and_shift)
        case event.command
        when :_shutdown
          cleanup_handler
          shutdown_handler(event)
        when :_perform
          perform_handler(event)
        when :_child_died
          child_died_handler(event.data[0], event.data[1])
        when :_child_shutdown
          child_shutdown_handler(event.data)
        when :_parent_died
          parent_died_handler(event.data[0], event.data[1])
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
