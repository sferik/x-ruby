# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The error that refuses a proxy URL that cannot be parsed has no cause, whose message would hold the password
  class ConnectionProxyCauseTest < Minitest::Test
    cover Core.const_get(:ConnectionProxy)

    def test_an_unparseable_proxy_url_raises_an_error_without_a_cause_holding_the_password
      error = assert_raises(ArgumentError) { Client.new(proxy_url: "http://user:se cret@example.com:8080") }

      assert_nil error.cause
      refute_includes error.full_message, "se cret"
    end
  end
end
