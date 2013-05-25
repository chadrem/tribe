module Tribe
  class Future
    def initialize
      @state = :initialized
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @result = nil
      @success = nil
      @success_callback = nil
      @failure_callback = nil

      return nil
    end

    def finished?
      @mutex.synchronize do
        return @state == :finished
      end
    end

    def result=(val)
      @mutex.synchronize do
        raise 'Result must only be set once.' unless @state == :initialized

        @result = val
        @state = :finished
        @condition.signal

        if val.is_a?(Exception)
          @failure_callback.call(val) if @failure_callback
        else
          @success_callback.call(val) if @success_callback
        end

        return nil
      end
    end

    def result
      @mutex.synchronize do
        raise 'Result must be set first.' unless @state == :finished

        return @result
      end
    end

    def wait
      @mutex.synchronize do
        return if @state == :finished

        @condition.wait(@mutex)

        return nil
      end
    end

    def success?
      @mutex.synchronize do
        raise 'Result must be set first.' unless @state == :finished

        return !@success.is_a?(Exception)
      end
    end

    def failure?
      return !success?
    end

    def success(&block)
      @mutex.synchronize do
        case @state
        when :initialized
          @success_callback = block
        when :finished
          yield(@result) unless @result.is_a?(Exception)
        else
          raise 'Invalid state.'
        end

        return nil
      end
    end

    def failure(&block)
      @mutex.synchronize do
        case @state
        when :initialized
          @failure_callback = block
        when :finished
          yield(@result) if @result.is_a?(Exception)
        else
          raise 'Invalid state.'
        end

        return nil
      end
    end
  end
end
