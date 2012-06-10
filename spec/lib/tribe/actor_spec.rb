require 'spec_helper'

class TestActor < Tribe::Actor
  attr_reader :some_arg

  def on_test_handler(arg)
    @some_arg = arg
  end
end

describe Tribe::Actor do
  before(:each) do
    @actor = TestActor.new
  end
end
