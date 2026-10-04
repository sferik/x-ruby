# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An error given the method and URI of a request names it by the method, in capitals, and the path of the URI
  class RequestLineTest < Minitest::Test
    cover Core.const_get(:RequestContext)

    def test_the_method_of_a_request_is_read_in_any_case
      ["POST", :POST, "post"].each do |http_method|
        error = NetworkError.new("went wrong", http_method:, uri: URI("https://api.x.com/2/users/1?user.fields=id"))

        assert_equal [:post, "POST /2/users/1: went wrong"], [error.http_method, error.message]
      end
    end

    def test_a_uri_without_a_path_is_named_as_the_request_for_its_root
      assert_equal "GET /: went wrong", NetworkError.new("went wrong", http_method: :get, uri: URI("https://api.x.com")).message
    end

    def test_an_error_given_a_method_or_a_uri_alone_names_no_request
      assert_equal [:get, nil, "went wrong"], NetworkError.new("went wrong", http_method: :get).then { |error| [error.http_method, error.uri, error.message] }
      assert_equal [nil, URI("https://api.x.com/2/users/1?user.fields=id"), "went wrong"], NetworkError.new("went wrong", uri: URI("https://api.x.com/2/users/1?user.fields=id")).then { |error| [error.http_method, error.uri, error.message] }
    end
  end
end
