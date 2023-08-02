require "test_helper"

class TestX < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::X::VERSION
  end
end
