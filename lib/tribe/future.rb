module Tribe
  class Future
    def initialize(actor = nil)
      @state = :initialized
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @result = nil
      @success_callback = nil
      @failure_callback = nil
      @actor = actor

      return nil
    end

    def finished?
      @mutex.synchronize do
        return @state == :finished
      end
    end

    def timeout?
      @mutex.synchronnize do
        return @state == :finished && @result.is_a?(Tribe::FutureTimeout)
      end
    end

    def result=(val)
      @mutex.synchronize do
        return unless @state == :initialized

        @timer.cancel if @timer

        @result = val
        @state = :finished
        @condition.signal

        if val.is_a?(Exception)
          if @failure_callback
            if @actor
              @actor.perform! do
                @failure_callback.call(val)
              end
            else
              @failure_callback.call(val)
            end
          end
        else
          if @success_callback
            if @actor
              @actor.perform! do
                @success_callback.call(val)
              end
            else
              @success_callback.call(val)
            end
          end
        end

        return nil
      end
    end

    def result
      @mutex.synchronize do
        raise Tribe::FutureNoResult.new('Result must be set first.') unless @state == :finished

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
        raise Tribe::FutureNoResult.new('Result must be set first.') unless @state == :finished

        return !@result.is_a?(Exception)
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
          unless @result.is_a?(Exception)
            if @actor
              @actor.perform! do
                block.call(@result)
              end
            else
              block.call(@result)
            end
          end
        else
          raise Tribe::FutureError.new('Invalid state.')
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
          if @result.is_a?(Exception)
            if @actor
              @actor.perform! do
                block.call(@result)
              end
            else
              block.call(@result)
            end
          end
        else
          raise Tribe::FutureError.new('Invalid state.')
        end

        return nil
      end
    end

    def timeout
      @mutex.synchronize do
      end
    end

    def timeout=(val)
      raise Tribe::FutureError.new('Timeout may only be set once.') if @timeout

      @timeout = val

      @timer = Workers::Timer.new(val) do
        begin
          raise Tribe::FutureTimeout.new("Timeout after #{@timeout} seconds.")
        rescue Tribe::FutureTimeout => e
          self.result = e
        end
      end
    end
  end
end
