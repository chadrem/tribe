module Tribe
  class Future
    def initialize(actor = nil)
      @state = :initialized
      @lock = Mutex.new
      @condition = ConditionVariable.new
      @result = nil
      @success_callback = nil
      @failure_callback = nil
      @actor = actor
      @timer = nil
      @timeout = nil

      return nil
    end

    def finished?
      @lock.synchronize do
        return @state == :finished
      end
    end

    def timeout?
      @lock.synchronnize do
        return @state == :finished && @result.is_a?(Tribe::FutureTimeout)
      end
    end

    def result=(val)
      @lock.synchronize do
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
      @lock.synchronize do
        raise Tribe::FutureNoResult.new('Result must be set first.') unless @state == :finished

        return @result
      end
    end

    def wait
      @lock.synchronize do
        return if @state == :finished

        # The wait can return even if nothing called @conditional.signal,
        # so we need to check to see if the condition actually changed.
        # See https://github.com/chadrem/workers/issues/7
        loop do
          @condition.wait(@lock)
          break if @state == :finished
        end

        return nil
      end
    end

    def success?
      @lock.synchronize do
        raise Tribe::FutureNoResult.new('Result must be set first.') unless @state == :finished

        return !@result.is_a?(Exception)
      end
    end

    def failure?
      return !success?
    end

    def success(&block)
      @lock.synchronize do
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
      @lock.synchronize do
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
      @lock.synchronize do
        @timeout
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
