require 'test_helper'

class FutureTestParentActor < TestActor
  attr_reader :result
  attr_reader :child
  attr_reader :future

  private

  def on_start_blocking(event)
    @child = spawn!(FutureTestChildActor)
    @future = future!(@child, :compute, event.data)

    wait!(@future)
    shutdown!
  end

  def on_start_non_blocking(event)
    @child = spawn!(FutureTestChildActor)
    @future = future!(@child, :compute, event.data)

    @future.success do |result|
      @result = result
      shutdown!
    end

    @future.failure do |exception|
      @result = exception
      shutdown!
    end
  end

  def on_start_non_blocking_delayed(event)
    @child = spawn!(FutureTestChildActor, {}, :supervise => true)
    @future = future!(@child, :compute, event.data)

    sleep(0.2)

    @future.success do |result|
      @result = result
      shutdown!
    end

    @future.failure do |exception|
      @result = exception
      shutdown!
    end
  end

  def on_start_blocking_timeout(event)
    @child = spawn!(FutureTestChildActor)
    @future = future!(@child, :sleep)
    @future.timeout = 0.1

    wait!(@future)
    shutdown!
  end

  def on_start_non_blocking_timeout(event)
    @child = spawn!(FutureTestChildActor)
    @future = future!(@child, :sleep)
    @future.timeout = 0.1

    @future.success do |result|
      @result = result
      shutdown!
    end

    @future.failure do |exception|
      @result = exception
      shutdown!
    end
  end
end

class FutureTestChildActor < Tribe::Actor
  attr_reader :success

  private

  def on_compute(event)
    event.data ** 2
  end

  def on_sleep(event)
    sleep(0.2)
    @success = true
  rescue Exception => e
    puts e.inspect
  end
end

#
# BLocking API tests.
#

class ActableFutureTest < Minitest::Test
  def test_blocking_success
    actor = FutureTestParentActor.new
    actor.run
    actor.direct_message!(:start_blocking, 10)

    poll { actor.dead? }

    assert_equal(100, actor.future.result )
  ensure
    actor.shutdown!
  end

  def test_blocking_exception
    actor = FutureTestParentActor.new
    actor.run
    actor.direct_message!(:start_blocking, nil)

    poll { actor.dead? }

    assert_kind_of(NoMethodError, actor.future.result)
  ensure
    actor.shutdown!
  end

  def test_blocking_timeout
    actor = FutureTestParentActor.new
    actor.run
    actor.direct_message!(:start_blocking_timeout)

    poll { actor.dead? }

    assert_equal(false, actor.future.success?)
    assert_kind_of(Tribe::FutureTimeout, actor.future.result)
  ensure
    actor.shutdown!
  end

  #
  # Non-blocking API tests.
  #

  def test_non_blocking_success
    actor = FutureTestParentActor.new
    actor.run
    actor.direct_message!(:start_non_blocking, 10)

    poll { actor.dead? }

    assert_equal(100, actor.future.result)
    assert_equal(100, actor.result)
  ensure
    actor.shutdown!
  end

  def test_non_blocking_success_delayed
    actor = FutureTestParentActor.new
    actor.run
    actor.direct_message!(:start_non_blocking_delayed, 10)

    poll { actor.dead? }

    assert_equal(100, actor.future.result)
    assert_equal(actor.future.result, actor.result)
  ensure
    actor.shutdown!
    actor.child.shutdown!
  end

  def test_non_blocking_exception
    actor = FutureTestParentActor.new
    actor.run
    actor.direct_message!(:start_non_blocking, nil)

    poll { actor.dead? }

    assert_kind_of(NoMethodError, actor.future.result)
    assert_equal(actor.future.result, actor.result)
  ensure
    actor.shutdown!
  end

  def test_non_blocking_exception_delayed
    actor = FutureTestParentActor.new
    actor.run
    actor.direct_message!(:start_non_blocking_delayed, nil)

    poll { actor.dead? }

    assert_kind_of(NoMethodError, actor.future.result)
    assert_equal(actor.future.result, actor.result)
  ensure
    actor.shutdown!
    actor.child.shutdown!
  end

  def test_non_blocking_timeout
    actor = FutureTestParentActor.new
    actor.run
    actor.direct_message!(:start_non_blocking_timeout)

    poll { actor.dead? }

    assert_kind_of(Tribe::FutureTimeout, actor.future.result)
    assert_equal(actor.future.result, actor.result)
  ensure
    actor.shutdown!
  end
end