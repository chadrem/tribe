module Tribe
  class Mailbox
    def initialize(pool)
      @pool = pool
      @messages = []
      @alive = true
      @lock = Mutex.new
      @owner_thread = nil
    end

    def push(event, &block)
      @lock.synchronize do
        return nil unless @alive

        @messages.push(event)
        @pool.perform { block.call } unless @owner_thread
      end

      return nil
    end

    def obtain_and_shift
      @lock.synchronize do
        return nil unless @alive

        if @owner_thread
          if @owner_thread == Thread.current
            return @messages.shift
          else
            return nil
          end
        else
          @owner_thread = Thread.current
          return @messages.shift
        end
      end
    end

    def release(&block)
      @lock.synchronize do
        return nil unless @owner_thread == Thread.current

        @owner_thread = nil
        @pool.perform { block.call } if @alive && @messages.length > 0
      end

      return nil
    end

    def kill
      @lock.synchronize do
        @alive = false
        @messages.clear
      end

      return nil
    end

    def alive?
      @lock.synchronize do
        return @alive
      end
    end
  end
end
