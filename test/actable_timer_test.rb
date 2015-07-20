require 'test_helper'

class TimerTestActor < TestActor
  attr_reader :count

  private

  def on_start_timer(event)
    @timer = timer!(0.01, :timer_fired)
  end

  def on_start_periodic_timer(event)
    @timer = periodic_timer!(0.01, :timer_fired)
  end

  def on_timer_fired(event)
    @count ||= 0
    @count += 1
  end
end

class ActableTimerTest < Minitest::Test
  def test_timer
    actor = TimerTestActor.new
    actor.run
    actor.direct_message!(:start_timer)

    poll { !actor.count.nil? }

    assert_equal(1, actor.count)
  ensure
    actor.shutdown!
  end

  def test_periodic_timer
    actor = TimerTestActor.new
    actor.run
    actor.direct_message!(:start_periodic_timer)

    poll { actor.count && actor.count > 1 }

    assert(actor.count > 1)
  ensure
    actor.shutdown!
  end
end