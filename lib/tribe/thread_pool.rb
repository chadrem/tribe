module Tribe
  class ThreadPool
    THREAD_COUNT = 64

    def initialize(options = {})
      @count = options[:count] || THREAD_COUNT

      @threads = []
      @lock = Mutex.new
      @queue = Queue.new

      spawn(@count)
    end

    def dispatch(&block)
      @queue.push([ :perform, block ])

      true
    end

    def shutdown
      @lock.synchronize do
        @count.times do
          @queue.push([ :shutdown ])
        end

        @threads.each { |thread| thread.join }

        true
      end
    end

    private
    def spawn(count)
      count.times do
        @lock.synchronize do
          thread = Thread.new { thread_main }
          @threads.push(thread)
        end
      end
    end

    def thread_main
      while (message = @queue.pop)
        case message[0]
        when :perform
          begin
            message[1].call
          rescue Exception => e
            puts "Worker caught exception: #{e.message}\n#{e.backtrace.join("\n")}"
          end
        when :shutdown
          return
        end
      end
    end
  end
end
