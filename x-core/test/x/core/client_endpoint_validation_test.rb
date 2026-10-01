# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientEndpointValidationTest < Minitest::Test
    cover_client

    NOT_A_URL = "it is not a valid URL; escape what a URL may not hold, such as a space"
    NOT_HTTP = "it does not name an http or https URL"

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_an_endpoint_that_holds_a_space_raises_argument_error_naming_it
      error = assert_raises(ArgumentError) { @client.get("users/by/username/a b") }

      assert_equal %(Invalid endpoint "users/by/username/a b": #{NOT_A_URL}), error.message
      assert_not_requested :any, /api\.x\.com/
    end

    def test_an_endpoint_with_a_malformed_percent_escape_raises_argument_error_naming_it
      error = assert_raises(ArgumentError) { @client.get("tweets?query=a%zz") }

      assert_equal %(Invalid endpoint "tweets?query=a%zz": #{NOT_A_URL}), error.message
      assert_not_requested :any, /api\.x\.com/
    end

    def test_an_endpoint_that_names_another_scheme_raises_argument_error_naming_it
      error = assert_raises(ArgumentError) { @client.get("foo:bar") }

      assert_equal %(Invalid endpoint "foo:bar": #{NOT_HTTP}), error.message
    end

    def test_an_endpoint_that_names_a_host_of_another_scheme_raises_argument_error_naming_it
      error = assert_raises(ArgumentError) { @client.get("ftp://api.x.com/2/users") }

      assert_equal %(Invalid endpoint "ftp://api.x.com/2/users": #{NOT_HTTP}), error.message
    end

    def test_an_endpoint_that_names_no_host_raises_argument_error_naming_it
      error = assert_raises(ArgumentError) { @client.get("https:users") }

      assert_equal %(Invalid endpoint "https:users": #{NOT_HTTP}), error.message
    end

    def test_a_write_to_an_invalid_endpoint_raises_before_it_is_sent
      error = assert_raises(ArgumentError) { @client.post("tweets/a b", {text: "Hello"}) }

      assert_equal %(Invalid endpoint "tweets/a b": #{NOT_A_URL}), error.message
      assert_not_requested :any, /api\.x\.com/
    end

    def test_a_valid_endpoint_that_names_another_host_is_sent_there
      stub_request(:get, "https://upload.x.com/1.1/media/upload.json?command=STATUS")
      @client.get("https://upload.x.com/1.1/media/upload.json", params: {command: "STATUS"})

      assert_requested :get, "https://upload.x.com/1.1/media/upload.json?command=STATUS"
    end
  end
end
