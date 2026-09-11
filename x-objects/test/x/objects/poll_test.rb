require_relative "../../test_helper"

module X
  class PollTest < Minitest::Test
    cover Poll

    def setup
      @poll = Poll.new({"id" => "1", "options" => [{"position" => 1, "label" => "Yes", "votes" => 2}],
                        "duration_minutes" => 60, "end_datetime" => "2024-01-02T03:04:05.000Z", "voting_status" => "closed"})
    end

    def test_class_configuration
      assert_equal "polls", Poll.includes_key
      assert_nil Poll.endpoint
    end

    def test_attributes
      assert_equal [{"position" => 1, "label" => "Yes", "votes" => 2}], @poll.options
      assert_equal 60, @poll.duration_minutes
      assert_equal Time.utc(2024, 1, 2, 3, 4, 5), @poll.end_datetime
      assert_equal "closed", @poll.voting_status
    end
  end
end
