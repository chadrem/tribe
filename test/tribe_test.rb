require 'test_helper'

class TribeTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Tribe::VERSION
  end
end
