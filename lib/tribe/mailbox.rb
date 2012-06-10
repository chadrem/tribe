module Tribe
  class Mailbox
    RETRIEVE_CAP = -1 # Disable's the cap by default.

    def initialize
      @messages = Queue.new
      @retrieve_lock = Mutex.new
    end

    # Returns true if it ran to completion, false if interupted.
    # Block must return true on success, false on failure.
    def retrieve_each(max = RETRIEVE_CAP, &block)
      @retrieve_lock.synchronize do
        count = 0

        @messages.length.times do
          if max >= 0 && count >= max
            break
          else
            count += 1
          end

          message = @messages.pop

          unless block.call(message)
            return false
          end
        end

        return true
      end
    end

    def deliver(message)
      @messages.push(message)
      true
    end
  end
end
