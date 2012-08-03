module Tribe
  class Actor
    attr_reader :name

    def initialize(options = {})
      run_hook(:pre_init)

      @alive = true
      @mailbox = Mailbox.new
      @name = (options[:name] || SecureRandom.uuid).freeze

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
      @mailbox.deliver([ method, args ])
      Tribe.dispatcher.send(:schedule, self)

      true
    end

    private
    def process
      @mailbox.retrieve_each do |message|
        begin
          send(message[0], *message[1])
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
