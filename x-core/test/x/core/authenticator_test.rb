# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class AuthenticatorTest < Minitest::Test
    cover Authenticator

    def setup
      @authenticator = Authenticator.new
    end

    def test_header
      assert_equal({}, @authenticator.header(nil))
    end

    def test_inspect
      assert_equal "#<X::Authenticator>", @authenticator.inspect
    end
  end
end
