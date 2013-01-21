module Tribe
  class Mailbox
    def initialize(options = {})
      @messages = []
      @mutex = Mutex.new
    end

    def push(event, &block)
      @mutex.synchronize do
        @messages.push(event)
        block.call unless @current_thread
      end

      return nil
    end

    def shift
      @mutex.synchronize do
        return nil if @current_thread && @current_thread != Thread.current

        @current_thread = Thread.current unless @current_thread

        return @messages.shift
      end
    end

    def release(&block)
      @mutex.synchronize do
        @current_thread = nil
        block.call if block && @messages.length > 0
      end

      return nil
    end

    def synchronize(&block)
      @mutex.synchronize do
        block.call
      end

      return nil
    end
  end
end
