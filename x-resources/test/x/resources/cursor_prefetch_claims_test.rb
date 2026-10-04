# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A page the caller fetches, or whose kept error the caller is raised, is let go by a prefetch thread that claimed it
  # and has yet to fetch it, so the thread neither requests it again nor keeps an error of its own for it
  class CursorPrefetchClaimsTest < Minitest::Test
    cover Resources.const_get(:Pages)

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        case query["pagination_token"]
        when nil then {"data" => [{"id" => "1"}], "meta" => {"next_token" => "p2"}}
        when "p2" then {"data" => [{"id" => "2"}], "meta" => {"next_token" => "p3"}}
        when "p3" then {"data" => [{"id" => "3"}], "meta" => {}}
        end
      })
      @cursor = Cursor.__send__(:build, User, "users/1/followers", client: @client, prefetch: true)
    end

    def test_a_page_the_caller_fails_to_fetch_before_its_prefetch_runs_is_requested_once_and_kept_no_error_for
      stub_failing_second_page
      started = []
      Thread.stub(:new, ->(&block) { started << block }) do
        @cursor.page(0)
        assert_raises(RuntimeError) { @cursor.page(1) }
      end
      started.each(&:call)

      assert_equal [[nil, "p2"], {}], [tokens, @cursor.instance_variable_get(:@pages).instance_variable_get(:@failures)]
    end

    def test_a_page_whose_kept_error_is_raised_is_let_go_by_a_prefetch_that_claimed_it_again
      stub_failing_second_page
      started = []
      Thread.stub(:new, ->(&block) { started << block }) do
        @cursor.page(0)
        started.shift.call
        @cursor.page(0)
        assert_raises(RuntimeError) { @cursor.page(1) }
      end
      started.each(&:call)

      assert_equal [[nil, "p2"], {}], [tokens, @cursor.instance_variable_get(:@pages).instance_variable_get(:@failures)]
    end

    private

    def stub_failing_second_page
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        raise "boom" if query["pagination_token"]

        {"data" => [{"id" => "1"}], "meta" => {"next_token" => "p2"}}
      })
    end

    def tokens = @client.queries.map { |query| query["pagination_token"] }
  end
end
