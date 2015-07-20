require 'test_helper'

class PerformTestActor < TestActor
end

class ActablePerformTest < Minitest::Test
  def test_perform
    success = false
    actor = PerformTestActor.new
    actor.run
    actor.perform! { success = true }
    actor.shutdown!

    poll { actor.dead? }

    assert_equal(:__perform__, actor.events[1].command)
    assert(success)
  ensure
    actor.shutdown!
  end

  def test_perform_exception
    actor = PerformTestActor.new
    actor.run
    actor.perform! { raise 'uh oh' }

    poll { actor.dead? }

    assert_kind_of(RuntimeError, actor.exception)
    assert_equal(false, actor.alive?)
  ensure
    actor.shutdown!
  end
end