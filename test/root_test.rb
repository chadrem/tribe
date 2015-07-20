require 'test_helper'

class RootTest < Minitest::Test
  def test_spawning
    child = Tribe.root.spawn!(Tribe::Actor)
  ensure
    child.shutdown!
  end

  def test_spawning_a_child_that_dies_does_not_kill_root
    child = Tribe.root.spawn!(Tribe::Actor)
    child.perform! { raise 'uh oh' }

    poll { child.dead? }

    assert_equal(false, child.alive?)
    assert(Tribe.root.alive?)
  ensure
    child.shutdown!
  end
end