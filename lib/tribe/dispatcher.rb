module Tribe
  class Dispatcher
    def initialize(options = {})
      @pool = ThreadPool.new(:count => options[:count])
    end

    def shutdown
      @pool.shutdown
    end

    private
    def schedule(&block)
      @pool.dispatch(&block)
    end
  end
end
