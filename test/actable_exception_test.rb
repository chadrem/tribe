require 'test_helper'

class ExceptionTestActor < TestActor
  attr_reader :success

  private

  def on_divide_by_zero(event)
    0 / 0
  end

  def on_exception(event)
    @success = true
  end
end

class ActableExceptionTest < Minitest::Test
  def test_exception
    actor = ExceptionTestActor.new
    actor.run
    actor.direct_message!(:divide_by_zero)

    poll { actor.dead? }

    assert_equal(:divide_by_zero, actor.events[1].command)
    assert_kind_of(ZeroDivisionError, actor.exception)
    assert_equal(false, actor.alive?)
    assert(actor.success)
  ensure
    actor.shutdown!
  end
end