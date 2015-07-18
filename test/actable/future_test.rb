require 'test_helper'

module Actable
  class FutureTestParentActor < TestActor
    attr_reader :result

    private

    def on_start_blocking(event)
      child = spawn(FutureTestChildActor)
      $child = child
      future = future!(child, :compute, event.data)

      wait(future)

      @result = future.result
    end

    def on_start_non_blocking(event)
      child = spawn(FutureTestChildActor)
      $child = child
      future = future!(child, :compute, event.data)

      future.success do |result|
        @result = result
      end

      future.failure do |exception|
        @result = exception
      end
    end
  end

  class FutureTestChildActor < Tribe::Actor
    private

    def on_compute(event)
      event.data ** 2
    end
  end

  class FutureTest < Minitest::Test
    def test_blocking_success
      actor = FutureTestParentActor.new
      actor.run
      actor.direct_message!(:start_blocking, 10)

      poll { actor.result }

      assert_equal(100, actor.result)
    ensure
      actor.shutdown!
    end

    def test_blocking_failure
      actor = FutureTestParentActor.new
      actor.run
      actor.direct_message!(:start_blocking, nil)

      poll { actor.result }

      assert_kind_of(NoMethodError, actor.result)
    ensure
      actor.shutdown!
    end

    def test_non_blocking_success
      actor = FutureTestParentActor.new
      actor.run
      actor.direct_message!(:start_non_blocking, 10)

      poll { actor.result }

      assert_equal(100, actor.result)
    ensure
      actor.shutdown!
    end

    def test_non_blocking_failure
      actor = FutureTestParentActor.new
      actor.run
      actor.direct_message!(:start_non_blocking, nil)

      poll { actor.result }

      assert_kind_of(NoMethodError, actor.result)
    ensure
      actor.shutdown!
    end
  end
end