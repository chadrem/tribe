module Tribe
  class Scheduler
    def initialize(opts = {})
      @count = opts[:count] || 20
      @workers = []
      @messages = Queue.new

      spawn(@count)
    end

    def shutdown
      @count.times do
        @messages.push({ :command => :shutdown })
      end

      @workers.each do |worker|
        worker.join
      end
    end

    private
    def schedule(&block)
      @messages.push({ :command => :perform, :task => block })
    end

    def spawn(count)
      count.times do
        worker = Worker.new(@messages)
        @workers.push(worker)
      end
    end
  end
end
