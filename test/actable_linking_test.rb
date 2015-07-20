require 'test_helper'

class ActableLinkingTest < Minitest::Test
  def test_parent_and_children_should_both_die
    top = Tribe::Actor.new
    middle = top.spawn!(Tribe::Actor)
    bottom = middle.spawn!(Tribe::Actor)

    middle.perform! { raise 'uh oh' }

    poll { top.dead? }
    poll { middle.dead? }
    poll { bottom.dead? }

    assert(top.dead?)
    assert(middle.dead?)
    assert(bottom.dead?)
    assert_kind_of(Tribe::ActorChildDied, top.exception)
    assert_kind_of(RuntimeError, middle.exception)
    assert_kind_of(Tribe::ActorParentDied, bottom.exception)
  end

  def test_parent_should_not_die_if_it_is_a_supervisor
    top = Tribe::Actor.new
    middle = top.spawn!(Tribe::Actor, {}, :supervise => true)
    bottom = middle.spawn!(Tribe::Actor)

    middle.perform! { raise 'uh oh' }

    poll { middle.dead? }
    poll { bottom.dead? }
    poll { top.alive? }

    assert(middle.dead?)
    assert(bottom.dead?)
    assert(top.alive?)
    assert_kind_of(Tribe::ActorParentDied, bottom.exception)
  end
end