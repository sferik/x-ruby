# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class CallbackErrorTest < Minitest::Test
    cover Streaming.const_get(:CallbackError)

    def test_a_callback_error_holds_the_error_a_callback_raised_and_its_message
      error = Streaming.const_get(:CallbackError).new(Errno::ECONNREFUSED.new("the hook failed"))

      assert_kind_of Errno::ECONNREFUSED, error.error
      assert_equal Errno::ECONNREFUSED.new("the hook failed").message, error.message
    end

    def test_a_tagging_callable_tags_the_error_its_callable_raises
      raised = Errno::ECONNREFUSED.new("the hook failed")
      error = assert_raises(Streaming.const_get(:CallbackError)) { Streaming.const_get(:CallbackError).tagging(->(_response) { raise raised }).call(:response) }

      assert_same raised, error.error
    end

    def test_a_tagging_callable_passes_its_callable_what_it_is_passed_and_returns_what_it_returns
      assert_equal [1, 2], Streaming.const_get(:CallbackError).tagging(->(*arguments) { arguments }).call(1, 2)
    end

    def test_no_callable_tags_nothing
      assert_nil Streaming.const_get(:CallbackError).tagging(nil)
    end
  end
end
