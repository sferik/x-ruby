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
  end
end
