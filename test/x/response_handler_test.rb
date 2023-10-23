require "hashie"
require_relative "../test_helper"

module X
  class ResponseHandlerTest < Minitest::Test
    cover ResponseHandler

    def setup
      @response_handler = ResponseHandler.new
      @uri = URI("http://example.com")
    end

    def get_http_response(uri = @uri)
      Net::HTTP.get_response(uri)
    end

    def test_success_response
      stub_request(:get, @uri.to_s).to_return(body: '{"message": "success"}',
        headers: {"Content-Type" => "application/json"})

      assert_equal({"message" => "success"}, @response_handler.handle(response: get_http_response))
    end

    def test_non_json_success_response
      stub_request(:get, @uri.to_s).to_return(body: "<html></html>", headers: {"Content-Type" => "text/html"})

      assert_nil @response_handler.handle(response: get_http_response)
    end

    def test_that_it_handles_204_no_content_response
      stub_request(:get, @uri.to_s).to_return(status: 204, headers: {"Content-Type" => "application/json"})

      assert_nil @response_handler.handle(response: get_http_response)
    end

    def test_bad_request_error
      stub_request(:get, @uri.to_s).to_return(status: 400)
      assert_raises(BadRequest) { @response_handler.handle(response: get_http_response) }
    end

    def test_unauthorized_error
      stub_request(:get, @uri.to_s).to_return(status: 401)
      assert_raises(Unauthorized) { @response_handler.handle(response: get_http_response) }
    end

    def test_unknown_error_code
      stub_request(:get, @uri.to_s).to_return(status: 418)
      assert_raises(Error) { @response_handler.handle(response: get_http_response) }
    end

    def test_too_many_requests_with_headers
      stub_request(:get, @uri.to_s).to_return(status: 429,
        headers: {"x-rate-limit-remaining" => "0"})
      exception = assert_raises(TooManyRequests) { @response_handler.handle(response: get_http_response) }

      assert_predicate exception.remaining, :zero?
    end

    def test_error_with_title_only
      stub_request(:get, @uri.to_s).to_return(status: [400, "Bad Request"], body: '{"title": "Some Error"}',
        headers: {"Content-Type" => "application/json"})
      exception = assert_raises(BadRequest) { @response_handler.handle(response: get_http_response) }

      assert_equal "Bad Request", exception.message
    end

    def test_error_with_detail_only
      stub_request(:get, @uri.to_s).to_return(status: [400, "Bad Request"], body: '{"detail": "Something went wrong"}',
        headers: {"Content-Type" => "application/json"})
      exception = assert_raises(BadRequest) { @response_handler.handle(response: get_http_response) }

      assert_equal "Bad Request", exception.message
    end

    def test_error_with_title_and_detail_error_message
      stub_request(:get, @uri.to_s).to_return(status: 400,
        body: '{"title": "Some Error", "detail": "Something went wrong"}',
        headers: {"Content-Type" => "application/json"})
      exception = assert_raises(BadRequest) { @response_handler.handle(response: get_http_response) }

      assert_equal("Some Error: Something went wrong", exception.message)
    end

    def test_error_with_error_message
      stub_request(:get, @uri.to_s).to_return(status: 400, body: '{"error": "Some Error"}',
        headers: {"Content-Type" => "application/json"})
      exception = assert_raises(BadRequest) { @response_handler.handle(response: get_http_response) }

      assert_equal("Some Error", exception.message)
    end

    def test_error_with_errors_array_message
      stub_request(:get, @uri.to_s).to_return(status: 400,
        body: '{"errors": [{"message": "Some Error"}, {"message": "Another Error"}]}',
        headers: {"Content-Type" => "application/json"})
      exception = assert_raises(BadRequest) { @response_handler.handle(response: get_http_response) }

      assert_equal("Some Error, Another Error", exception.message)
    end

    def test_error_with_errors_message
      stub_request(:get, @uri.to_s).to_return(status: 400, body: '{"errors": {"message": "Some Error"}}',
        headers: {"Content-Type" => "application/json"})
      exception = assert_raises(BadRequest) { @response_handler.handle(response: get_http_response) }

      assert_empty exception.message
    end

    def test_non_json_error_response
      stub_request(:get, @uri.to_s).to_return(status: [400, "Bad Request"], body: "<html>Bad Request</html>",
        headers: {"Content-Type" => "text/html"})
      exception = assert_raises(BadRequest) { @response_handler.handle(response: get_http_response) }

      assert_equal "Bad Request", exception.message
    end

    def test_default_response_objects
      stub_request(:get, @uri.to_s).to_return(body: '{"array": [1, 2, 2, 3]}',
        headers: {"Content-Type" => "application/json"})
      hash = @response_handler.handle(response: get_http_response)

      assert_kind_of Hash, hash
      assert_kind_of Array, hash["array"]
      assert_equal [1, 2, 2, 3], hash["array"]
    end

    def test_custom_response_objects
      response_handler = ResponseHandler.new(object_class: Hashie::Mash, array_class: Set)
      stub_request(:get, @uri.to_s).to_return(body: '{"array": [1, 2, 2, 3]}',
        headers: {"Content-Type" => "application/json"})
      mash = response_handler.handle(response: get_http_response)

      assert_kind_of Hashie::Mash, mash
      assert_kind_of Set, mash.array
      assert_equal Set.new([1, 2, 2, 3]), mash.array
    end
  end
end
