require 'test_helper'

module Actable
  class ShutdownTestActor < TestActor
    attr_reader :success

    private

    def on_shutdown(event)
      @success = true
    end
  end


  class ShutdownTest < Minitest::Test
    def test_shutdown
      actor = ShutdownTestActor.new
      actor.run
      actor.shutdown!

      poll { actor.success }

      assert_equal(:__shutdown__, actor.events[1].command)
      assert(actor.success)
    ensure
      actor.shutdown!
    end
  end
end