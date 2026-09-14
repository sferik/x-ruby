require_relative "../../test_helper"

module X
  class ResponseParserBuilderTest < Minitest::Test
    cover ResponseParser

    def setup
      @response_parser = ResponseParser.new
      @uri = URI("http://example.com")
    end

    def response = Net::HTTP.get_response(@uri)

    def stub_json(body:)
      stub_request(:get, @uri.to_s).to_return(status: 200, body:, headers: {"Content-Type" => "application/json"})
    end

    def test_response_builder_receives_the_whole_body_as_hashes
      stub_json(body: '{"data": {"id": "1", "public_metrics": {"like_count": 2}}}')
      built = @response_parser.parse(response:, object_class: ResponseBuilder, array_class: Set)

      assert_equal({"data" => {"id" => "1", "public_metrics" => {"like_count" => 2}}}, built[:body])
      assert_instance_of Hash, built[:body]["data"]["public_metrics"]
    end

    def test_response_builder_receives_the_client
      stub_json(body: "{}")

      assert_equal :client, @response_parser.parse(response:, object_class: ResponseBuilder, client: :client)[:client]
    end

    def test_response_builder_is_skipped_for_invalid_json
      stub_request(:get, @uri.to_s).to_return(status: 200, body: "not json")

      assert_nil @response_parser.parse(response:, object_class: ResponseBuilder)
    end

    def test_decode_into_the_default_classes
      assert_equal({"data" => {"id" => "1"}}, @response_parser.decode('{"data": {"id": "1"}}'))
    end

    def test_decode_without_a_client
      assert_nil @response_parser.decode("{}", object_class: ResponseBuilder)[:client]
    end

    def test_decode_raises_for_invalid_json
      assert_raises(JSON::ParserError) { @response_parser.decode("not json", object_class: ResponseBuilder) }
    end
  end
end
