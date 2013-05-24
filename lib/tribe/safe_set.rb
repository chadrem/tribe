# Ruby's built in Set class may not be thread safe.
# This class wraps each method to make it so.
# More methods will be wrapped as needed.

module Tribe
  class SafeSet
    def initialize
      @mutex = Mutex.new
      @set = Set.new

      return nil
    end

    def add(item)
      @mutex.synchronize do
        @set.add(item)
      end

      return self
    end

    def delete(item)
      @mutex.synchronize do
        @set.delete(item)
      end

      return self
    end

    def each(&block)
      @mutex.synchronize do
        @set.each do |item|
          yield(item)
        end
      end

      return self
    end
  end
end
