require_relative "../../test_helper"

module X
  class ClientResponseBuilderTest < Minitest::Test
    include StreamHelpers

    cover_client
    cover StreamingClient

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    X::Core::RequestBuilder::HTTP_METHODS.each_key do |http_method|
      define_method :"test_#{http_method}_request_passes_itself_to_a_response_builder" do
        stub_request(http_method, "https://api.x.com/2/tweets")
          .to_return(body: '{"data": {"id": "1"}}', headers: {"Content-Type" => "application/json"})
        built = @client.public_send(http_method, "tweets", object_class: ResponseBuilder)

        assert_equal({"data" => {"id" => "1"}}, built[:body])
        assert_same @client, built[:client]
      end
    end

    def test_stream_passes_itself_to_a_response_builder
      results = with_stubbed_stream(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n"]) do
        stream_and_collect("tweets/search/stream", object_class: ResponseBuilder)
      end

      assert_equal({"data" => {"id" => "1"}}, results.first[:body])
      assert_same @client, results.first[:client]
    end
  end
end
