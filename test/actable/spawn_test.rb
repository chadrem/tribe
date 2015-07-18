require 'test_helper'

module Actable
  class SpawnTestParentActor < TestActor
    attr_reader :success
    attr_reader :dead_child
    attr_reader :child_exception

    private

    def on_child_died(event)
      @success = true
      @dead_child = event.data[:child]
      @child_exception = event.data[:exception]
    end
  end

  class SpawnTestChildActor < Tribe::Actor
    attr_reader :success
    attr_reader :dead_parent
    attr_reader :parent_exception

    def on_parent_died(event)
      @success = true
      @dead_parent = event.data[:parent]
      @parent_exception = event.data[:exception]
    end
  end

  class SpawnTest < Minitest::Test
    def test_spawn
      parent = SpawnTestParentActor.new
      parent.run
      child = parent.spawn(SpawnTestChildActor)

      assert_kind_of(SpawnTestChildActor, child)
    ensure
      parent.shutdown!
      child.shutdown!
    end

    def test_child_death_kills_parent
      parent = SpawnTestParentActor.new
      parent.run
      child = parent.spawn(SpawnTestChildActor)
      child.perform! { raise 'uh oh' }

      poll { !parent.alive? }

      assert_equal(false, parent.alive?)
      assert_equal(false, child.alive?)
      assert(parent.success)
      assert_kind_of(Tribe::ActorChildDied, parent.exception)
      assert_kind_of(RuntimeError, child.exception)
      assert_equal(child, parent.dead_child)
      assert_equal(child.exception, parent.child_exception)
    end

    def test_parent_death_kills_child
      parent = SpawnTestParentActor.new
      parent.run
      child = parent.spawn(SpawnTestChildActor)
      parent.perform! { raise 'uh oh' }

      poll { !child.alive? }

      assert_equal(false, parent.alive?)
      assert_equal(false, child.alive?)
      assert(child.success)
      assert_kind_of(RuntimeError, parent.exception)
      assert_kind_of(Tribe::ActorParentDied, child.exception)
      assert_equal(parent, child.dead_parent)
      assert_equal(parent.exception, child.parent_exception)
    end
  end
end