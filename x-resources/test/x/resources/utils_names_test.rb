# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Resources
    class UtilsNamesTest < Minitest::Test
      cover Utils

      def test_username_strips_a_leading_at_sign
        assert_equal "sferik", Utils.username("@sferik")
        assert_equal "sferik", Utils.username("sferik")
        assert_equal "s@ferik", Utils.username("s@ferik")
        assert_equal "1", Utils.username(1)
      end

      def test_authenticator_of_a_client_with_one
        authenticator = Object.new
        client = Struct.new(:authenticator).new(authenticator)

        assert_same authenticator, Utils.authenticator_of(client)
      end

      def test_authenticator_of_a_client_without_one
        assert_nil Utils.authenticator_of(Object.new)
      end
    end
  end
end
