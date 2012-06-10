module Tribe
  class Worker
    def initialize(queue, options = {})
      @queue = queue
      @thread = Thread.new { main }
    end

    def join
      @thread.join
    end

    private
    def main
      while (message = @queue.pop)
        case message[:command]
        when :shutdown
          return
        when :perform
          begin
            message[:task].call
          rescue Exception => e
            puts "Worker caught exception: #{e.message}\n#{e.backtrace.join("\n")}"
          end
        end
      end
    end
  end
end
