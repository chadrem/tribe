require 'test_helper'

module Actable
  class PerformTestActor < TestActor
  end

  class PerformTest < Minitest::Test
    def test_perform
      success = false
      actor = PerformTestActor.new
      actor.run
      actor.perform! { success = true }

      poll { success }

      assert_equal(:__perform__, actor.events[1].command)
      assert(success)
    ensure
      actor.shutdown!
    end

    def test_perform_exception
      actor = PerformTestActor.new
      actor.run
      actor.perform! { raise 'uh oh' }

      poll { actor.exception }

      assert_kind_of(RuntimeError, actor.exception)
      assert_equal(false, actor.alive?)
    ensure
      actor.shutdown!
    end
  end
end