module Tribe
  class Mailbox
    def initialize(options = {})
      @messages = []
      @mutex = Mutex.new
    end

    def push(event)
      @mutex.synchronize do
        @messages.push(event)
      end
    end

    def shift
      @mutex.synchronize do
        return nil if @current_thread && @current_thread != Thread.current

        @current_thread = Thread.current unless @current_thread

        @messages.shift
      end
    end

    def release(&requeue_block)
      @mutex.synchronize do
        @current_thread = nil

        if requeue_block && @messages.length > 0
          requeue_block.call
        end
      end
    end

    def synchronize(&block)
      @mutex.synchronize do
        block.call
      end
    end

    # def obtain
    #   @mutex.synchronize do
    #     return false if @current_thread && @current_thread != Thread.current

    #     @current_thread = Thread.current

    #     return true
    #   end
    # end

    # def release
    #   @mutex.synchronize do
    #     return false unless @current_thread && @current_thread == Thread.current

    #     @current_thread = nil

    #     return true
    #   end
    # end
  end
end
