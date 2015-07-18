require 'coveralls'
Coveralls.wear!

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'tribe'

class TestActor
  include Tribe::Actable

  attr_reader :events

  def initialize(options = {})
    @events = []
    @test_options = options
  end

  def run
    init_actable(@test_options)
  end

  def event_handler(event)
    @events << event
    super
  end
end

# Poll until seconds pass or the block returns true.
def poll(seconds = 1)
  count = seconds * 100
  while count > 0 && !yield
    count -= 1
    sleep 0.01
  end
end


require 'minitest/autorun'
