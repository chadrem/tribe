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
        return @set.add(item)
      end
    end

    def delete(item)
      @mutex.synchronize do
        return @set.delete(item)
      end
    end

    def delete?(item)
      @mutex.synchronize do
        return @set.delete?(item)
      end
    end

    def each(&block)
      @mutex.synchronize do
        return @set.each do |item|
          yield(item)
        end
      end
    end

    def clear
      @mutex.synchronize do
        return @set.clear
      end
    end

    def size
      @mutex.synchronize do
        return @set.size
      end
    end

    def to_a
      @mutex.synchronize do
        return @set.to_a
      end
    end
  end
end
