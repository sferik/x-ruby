# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class AuthenticatorRequestTest < Minitest::Test
    cover Core.const_get(:AuthenticatorRequest)

    def setup
      request = Net::HTTP::Post.new(URI("https://api.x.com/2/tweets?a=1"))
      request.body = '{"text":"Hi"}'
      request["Content-Type"] = "application/json"
      @request = Core.const_get(:AuthenticatorRequest).new(request)
    end

    def test_reads_the_method_as_a_symbol
      assert_equal :post, @request.http_method
    end

    def test_reads_the_uri_and_the_body
      assert_equal [URI("https://api.x.com/2/tweets?a=1"), '{"text":"Hi"}'], [@request.uri, @request.body]
    end

    def test_reads_a_header_by_its_name_in_any_case
      assert_equal ["application/json", "application/json", nil], [@request["Content-Type"], @request["content-type"], @request["X-None"]]
    end

    def test_answers_nothing_else_of_the_request
      refute_respond_to @request, :path
      refute_respond_to @request, :each_header
    end
  end
end
