# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A problem tells its kind by its type, whatever the host of the API that named it
  class ProblemKindTest < Minitest::Test
    cover Problem

    def test_not_found
      assert_predicate Problem.new({"type" => "https://api.x.com/2/problems/resource-not-found"}), :not_found?
      refute_predicate Problem.new({"type" => "https://api.x.com/2/problems/not-authorized-for-resource"}), :not_found?
      refute_predicate Problem.new({}), :not_found?
    end

    def test_disconnect
      assert_predicate Problem.new({"type" => "https://api.twitter.com/2/problems/operational-disconnect"}), :disconnect?
      refute_predicate Problem.new({"type" => "https://api.x.com/2/problems/operational-disconnect-soon"}), :disconnect?
      refute_predicate Problem.new({"type" => "https://api.x.com/2/problems/streaming-connection"}), :disconnect?
      refute_predicate Problem.new({"title" => "operational-disconnect"}), :disconnect?
    end

    def test_usage_capped
      assert_predicate Problem.new({"type" => "https://api.twitter.com/2/problems/usage-capped"}), :usage_capped?
      refute_predicate Problem.new({"type" => "https://api.x.com/2/problems/usage-capped-soon"}), :usage_capped?
      refute_predicate Problem.new({"type" => "https://api.x.com/2/problems/rate-limit"}), :usage_capped?
      refute_predicate Problem.new({"title" => "UsageCapExceeded"}), :usage_capped?
    end
  end
end
