module Tribe
  module Actable
    include Workers::Helpers

    private

    #
    # Initialization method.
    # Notes: Call this in your constructor.
    #

    def init_actable(options = {})
      # Symbols aren't GCed in JRuby so force string names.
      if options[:name] && !options[:name].is_a?(String)
        raise Tribe::ActorNameError.new('Name must be a string.')
      end

      @_actable = Tribe::ActorState.new

      @_actable.dedicated = options[:dedicated] || false
      @_actable.pool = @_actable.dedicated ? Workers::Pool.new(:size => 1) : (options[:pool] || Workers.pool)
      @_actable.mailbox = Tribe::Mailbox.new(@_actable.pool)
      @_actable.registry = options[:registry] || Tribe.registry
      @_actable.logger = Workers::LogProxy.new(options[:logger] || Tribe.logger)
      @_actable.scheduler = options[:scheduler] || Workers.scheduler
      @_actable.name = options[:name]
      @_actable.parent = options[:parent]
      @_actable.children = Tribe::SafeSet.new
      @_actable.supervisees = Tribe::SafeSet.new
      @_actable.timers = Tribe::SafeSet.new

      @_actable.registry.register(self)

      direct_message!(:__initialize__)
    end

    #
    # Thread safe public methods.
    # Notes: These are the methods that actors use to communicate with each other.
    #        Actors should avoid sharing mutable state in order to remain thread safe.
    #        Methods with a ! are designed for asynchronous communication.
    #

    public

    def deliver_event!(event)
      @_actable.mailbox.push(event) do
        process_events
      end

      nil
    end

    def direct_message!(command, data = nil, src = nil)
      deliver_event!(Tribe::Event.new(command, data, src))

      nil
    end

    def shutdown!
      direct_message!(:__shutdown__)
    end

    def perform!(&block)
      direct_message!(:__perform__, block)
    end

    def spawn!(klass, actor_options = {}, spawn_options = {})
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

      @_actable.children.add(child)

      if spawn_options[:supervise]
        @_actable.supervisees.add(child)
      end

      child
    end

    def alive?
      @_actable.mailbox.alive?
    end

    def dead?
      !alive?
    end

    def name
      @_actable.name
    end

    def identifier
      @_actable.name ? "#{object_id}:#{@_actable.name}" : object_id
    end

    def exception
      @_actable.exception
    end

    def registry
      @_actable.registry
    end

    def pool
      @_actable.pool
    end

    def logger
      @_actable.logger
    end

    #
    # Private command handlers.
    # Notes: These methods are designed to be overriden in order to respond to actor system events.
    #

    private

    def on_initialize(event)
    end

    def on_exception(event)
    end

    def on_shutdown(event)
    end

    def on_child_died(event)
    end

    def on_child_shutdown(event)
    end

    def on_parent_died(event)
    end

    #
    # Private event system methods.
    # Notes: These methods are designed to be overriden by advanced users only.  Overriding is very rare!
    #

    private

    # All system commands are prefixed with an underscore.
    def process_events
      while (event = @_actable.mailbox.obtain_and_shift)
        event_handler(event)
      end

    rescue Exception => exception
      cleanup_handler(exception)
      exception_handler(exception)
    ensure
      @_actable.mailbox.release do
        process_events
      end

      nil
    end

    def event_handler(event)
      case event.command
      when :__initialize__
        initialize_handler(event)
      when :__shutdown__
        cleanup_handler
        shutdown_handler(event)
      when :__perform__
        perform_handler(event)
      when :__child_died__
        child_died_handler(event.data[0], event.data[1])
      when :__child_shutdown__
        child_shutdown_handler(event.data)
      when :__parent_died__
        parent_died_handler(event.data[0], event.data[1])
      when :initialize, :shutdown, :perform, :child_died, :child_shutdown, :parent_died
        raise ActorReservedCommand.new("Reserved commands are not allowed (command=#{event.command}).")
      else
        custom_event_handler(event)
      end
    end

    def custom_event_handler(event)
      result = nil
      @_actable.active_event = event

      begin
        result = send("on_#{event.command}", event)
      rescue Exception => e
        result = e
        raise
      ensure
        if event.future && @_actable.active_event
          event.future.result = result
        end
        @_actable.active_event = nil
      end

      nil
    end

    def initialize_handler(event)
      on_initialize(event)
    end

    def exception_handler(exception)
      if @_actable.parent
        @_actable.parent.direct_message!(:__child_died__, [self, exception])
      end

      @_actable.children.each { |c| c.direct_message!(:__parent_died__, [self, exception]) }
      @_actable.children.clear
      @_actable.supervisees.clear

      log_exception_handler(exception)
      on_exception(Event.new(:exception, {:exception => exception}))

      nil
    end

    def log_exception_handler(exception)
      logger.error("EXCEPTION: #{exception.message}\n#{exception.backtrace.join("\n")}\n--")
    end

    def shutdown_handler(event)
      if @_actable.parent
        @_actable.parent.direct_message!(:__child_shutdown__, self)
      end

      @_actable.children.each { |c| c.shutdown! }
      @_actable.children.clear
      @_actable.supervisees.clear

      on_shutdown(Event.new(:shutdown, {}))

      nil
    end

    def perform_handler(event)
      event.data.call

      nil
    end

    def cleanup_handler(exception = nil)
      @_actable.exception = exception
      @_actable.pool.shutdown if @_actable.dedicated
      @_actable.mailbox.kill
      @_actable.registry.unregister(self)
      @_actable.timers.each { |t| t.cancel } if @_actable.timers

      nil
    end

    def child_died_handler(child, exception)
      @_actable.children.delete(child)
      supervising = !!@_actable.supervisees.delete?(child)

      on_child_died(Event.new(:child_died, {:child => child, :exception => exception}))

      if !supervising
        raise Tribe::ActorChildDied.new("#{child.identifier} died.")
      end

      nil
    end

    def child_shutdown_handler(child)
      @_actable.children.delete(child)
      @_actable.supervisees.delete(child)

      on_child_shutdown(Event.new(:child_shutdown, {:child => child}))

      nil
    end

    def parent_died_handler(parent, exception)
      on_parent_died(Event.new(:parent_died, {:parent => parent, :exception => exception}))
      raise Tribe::ActorParentDied.new("#{parent.identifier} died.")

      nil
    end

    #
    # Private API methods.
    # Notes: Use these methods internally in your actor.
    #

    private

    def message!(dest, command, data = nil)
      event = Tribe::Event.new(command, data, self)

      dest.deliver_event!(event)

      nil
    end

    def future!(dest, command, data = nil)
      event = Tribe::Event.new(command, data, self)
      event.future = future = Tribe::Future.new(self)

      dest.deliver_event!(event)

      future
    end

    def timer!(delay, command, data = nil)
      timer = Workers::Timer.new(delay, :scheduler => @_actable.scheduler) do
        @_actable.timers.delete(timer)
        direct_message!(command, data)
      end

      @_actable.timers.add(timer)

      timer
    end

    def periodic_timer!(delay, command, data = nil)
      timer = Workers::PeriodicTimer.new(delay, :scheduler => @_actable.scheduler) do
        direct_message!(command, data)
        unless alive?
          @_actable.timers.delete(timer)
          timer.cancel
        end
      end

      @_actable.timers.add(timer)

      timer
    end

    def forward!(dest)
      dest.deliver_event!(@_actable.active_event)
      @_actable.active_event = nil

      nil
    end

    # Wrap blocking code using this method to automatically expand/contract the pool.
    # This way you avoid potential thread starvation. Not needed for dedicated actors
    # since they already have their own thread.
    def blocking!
      if @_actable.dedicated
        yield
      else
        pool.expand(1)
        begin
          yield
        ensure
          pool.contract(1)
        end
      end
    end

    def wait!(future)
      blocking! do
        future.wait
      end
    end
  end
end
