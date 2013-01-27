module Tribe
  module Actable
    include Workers::Helpers

    def init_actable(options = {})
      @logger = Workers::LogProxy.new(options[:logger])
      @dedicated = options[:dedicated] || false
      @mailbox = options[:mailbox] || Tribe::Mailbox.new
      @registry = options[:registry] || Tribe.registry
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

    def alive?
      @mailbox.synchronize { return @alive }
    end

    def name
      return @name
    end

    def identifier
      return @name ? "#{object_id}:#{@name}" : object_id
    end

    private

    def process_events
      while (event = @mailbox.shift)
        case event.command
        when :shutdown
          shutdown_handler(event)
          @pool.shutdown if @dedicated
          @mailbox.synchronize { @alive = false }
        else
          process_event(event)
        end
      end

    rescue Exception => e
      @alive = false
      @pool.shutdown if @dedicated
      exception_handler(e)
    ensure
      @mailbox.release do
        @pool.perform { process_events }
      end

      return nil
    end

    def process_event(event)
      send("on_#{event.command}", event)
    end

    def exception_handler(e)
    end

    def shutdown_handler(event)
    end
  end
end
