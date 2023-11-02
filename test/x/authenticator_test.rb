require_relative "../test_helper"

module X
  class AuthenticatorTest < Minitest::Test
    cover Authenticator

    def setup
      @authenticator = Authenticator.new
    end

    def test_header
      assert_kind_of Hash, @authenticator.header(nil)
      assert_empty @authenticator.header(nil)["Authorization"]
    end
  end
end
