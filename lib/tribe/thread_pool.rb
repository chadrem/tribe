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
      @queue.push({ :command => :perform, :task => block })

      true
    end

    def shutdown
      @lock.synchronize do
        @count.times do
          @queue.push({ :command => :shutdown })
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
        case message[:command]
        when :perform
          begin
            message[:task].call
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
