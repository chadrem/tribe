require 'test_helper'

class SupervisorTestParentActor < TestActor
  attr_reader :child
  attr_reader :result

  private

  def on_start_supervised(event)
    @child = spawn!(SupervisorTestChildActor, {}, :supervise => true)
  end

  def on_start_unsupervised(event)
    @child = spawn!(SupervisorTestChildActor, {}, :supervise => false)
  end

  def on_child_died(event)
    @result = event.data
  end
end

class SupervisorTestChildActor < Tribe::Actor
  private
end

class ActableSupervisorTest < Minitest::Test
  def test_child_death_does_not_kill_parent_when_supervised
    parent = setup_parent(:start_supervised)

    assert(parent.child, parent.result[:child])
    assert_kind_of(RuntimeError, parent.result[:exception])
    assert(parent.alive?)
  end

  def test_child_death_does_kill_parent_when_unsupervised
    parent = setup_parent(:start_unsupervised)

    assert(parent.child, parent.result[:child])
    assert_kind_of(RuntimeError, parent.result[:exception])
    assert(parent.dead?)
  end

  private

  def setup_parent(command)
    parent = SupervisorTestParentActor.new
    parent.run
    parent.direct_message!(command)

    poll { parent.child }

    parent.child.perform! { raise 'uh oh' }

    poll { parent.child.dead? }

    sleep(0.1)

    parent
  end
end