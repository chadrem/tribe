require 'test_helper'

class TimerTestActor < TestActor
  attr_reader :count

  private

  def on_start_timer(event)
    @mode = :once
    @timer = timer!(0.01, :fire)
  end

  def on_start_periodic_timer(event)
    @mode = :periodic
    @timer = periodic_timer!(0.01, :fire)
  end

  def on_fire(event)
    @count ||= 0
    @count += 1
    shutdown! if @mode == :once || @count > 5
  end
end

class ActableTimerTest < Minitest::Test
  def test_timer
    actor = TimerTestActor.new
    actor.run
    actor.direct_message!(:start_timer)

    poll { actor.dead? }

    assert_equal(1, actor.count)
  ensure
    actor.shutdown!
  end

  def test_periodic_timer 
    actor = TimerTestActor.new
    actor.run
    actor.direct_message!(:start_periodic_timer)

    poll { actor.dead? }

    assert(actor.count > 5)
  ensure
    actor.shutdown!
  end
end