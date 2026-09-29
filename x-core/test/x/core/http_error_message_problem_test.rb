# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The message of an error whose body describes a problem by its title and detail says each once
  class HTTPErrorMessageProblemTest < Minitest::Test
    cover HTTPError

    JSON_HEADERS = {"Content-Type" => "application/json"}.freeze

    def setup
      @response_parser = Core::ResponseParser.new
      @uri = URI("http://example.com")
    end

    def response = Net::HTTP.get_response(@uri)

    def stub_json(status: 200, body: "{}")
      stub_request(:get, @uri.to_s).to_return(status:, body:, headers: JSON_HEADERS)
    end

    def test_error_whose_detail_is_its_title_says_it_once
      stub_json(status: [401, "Unauthorized"], body: '{"title": "Unauthorized", "type": "about:blank", "status": 401, "detail": "Unauthorized"}')

      assert_equal "Unauthorized", assert_raises(Unauthorized) { @response_parser.parse(response:) }.message
    end

    def test_error_whose_detail_is_its_title_says_it_in_place_of_the_status
      stub_json(status: [400, "Bad Request"], body: '{"title": "Invalid Request", "detail": "Invalid Request"}')

      assert_equal "Invalid Request", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_error_whose_detail_differs_from_its_title_in_case_alone_says_both
      stub_json(status: 400, body: '{"title": "Invalid Request", "detail": "invalid request"}')

      assert_equal "Invalid Request: invalid request", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end
  end
end
