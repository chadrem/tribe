require 'test_helper'

class InitializationTestActor < TestActor
  attr_reader :success

  private

  def on_initialize(event)
    @success = true
  end
end


class ActableInitializationTest < Minitest::Test
  def test_initialization
    actor = InitializationTestActor.new
    actor.run

    poll { actor.success }

    assert_equal(:__initialize__, actor.events[0].command)
    assert(actor.alive?)
  ensure
    actor.shutdown!
  end
end