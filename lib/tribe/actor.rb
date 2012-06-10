module Tribe
  class Actor
    attr_reader :name

    def initialize(options = {})
      run_hook(:pre_init)

      @alive = true
      @mailbox = Mailbox.new
      @name = options[:name].freeze

      Tribe.registry.register(self)

      run_hook(:post_init)
    end

    def method_missing(method, *args, &block)
      m = method.to_s
      bang = m[-1] == '!'

      if bang && respond_to?(m.chop!)
        tell(m, *args)
      else
        super
      end
    end

    def tell(method, *args)
      message = { :method => method, :args => args }
      @mailbox.deliver(message)

      Tribe.dispatcher.send(:schedule) do
        process
      end

      true
    end

    private
    def process
      @mailbox.retrieve_each do |message|
        begin
          send(message[:method], *message[:args])
          true
        rescue Exception => e
          puts "Actor died while processing: #{e.message}\n#{e.backtrace.join("\n")}"
          false
        end
      end
    end

    def terminate
      @alive = false
      Tribe.registry.unregister(self)
    end

    def run_hook(hook)
      send(hook) if respond_to?(hook, true)
    end
  end
end
