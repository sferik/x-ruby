$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

unless $PROGRAM_NAME.include?("mutant")
  require "simplecov"

  SimpleCov.start "strict"
end

require "securerandom"
require "minitest/autorun"
require "minitest/mock"
require "mutant/minitest/coverage"
require "webmock/minitest"
require "x/core"

TEST_BEARER_TOKEN = "TEST_BEARER_TOKEN".freeze
TEST_API_KEY = "TEST_API_KEY".freeze
TEST_API_KEY_SECRET = "TEST_API_KEY_SECRET".freeze
TEST_ACCESS_TOKEN = "TEST_ACCESS_TOKEN".freeze
TEST_ACCESS_TOKEN_SECRET = "TEST_ACCESS_TOKEN_SECRET".freeze
TEST_OAUTH_NONCE = "TEST_OAUTH_NONCE".freeze
TEST_OAUTH_TIMESTAMP = Time.utc(1983, 11, 24).to_i.to_s
TEST_CLIENT_ID = "TEST_CLIENT_ID".freeze
TEST_CLIENT_SECRET = "TEST_CLIENT_SECRET".freeze
TEST_REFRESH_TOKEN = "TEST_REFRESH_TOKEN".freeze

def test_oauth_credentials
  {
    api_key: TEST_API_KEY,
    api_key_secret: TEST_API_KEY_SECRET,
    access_token: TEST_ACCESS_TOKEN,
    access_token_secret: TEST_ACCESS_TOKEN_SECRET
  }
end

def test_oauth2_credentials
  {
    client_id: TEST_CLIENT_ID,
    client_secret: TEST_CLIENT_SECRET,
    access_token: TEST_ACCESS_TOKEN,
    refresh_token: TEST_REFRESH_TOKEN
  }
end

# Fix the nonce and the timestamp that OAuth headers are signed with, so signatures are deterministic
def with_fixed_oauth_params(nonce: TEST_OAUTH_NONCE, time: Time.utc(1983, 11, 24), &block)
  SecureRandom.stub(:hex, nonce) do
    Time.stub(:now, time, &block)
  end
end

# Build a GET request for the given URL
def get_request(url = "https://example.com/")
  Net::HTTP::Get.new(URI(url))
end

# A class that builds objects from a whole response, as the object layer's resources do
class ResponseBuilder
  # Return what it was given, so a test can see the body and the client
  def self.from_response(body, client:) = {body:, client:}
end

# Stub a streaming client's connection and collect what it yields
module StreamHelpers
  # The streaming client of a client, which reconnects no stream, since a stub delivers its chunks once
  def streaming(client: @client)
    @streaming ||= {}
    @streaming[client] ||= client.streaming(max_reconnects: 0)
  end

  def stream_and_collect(endpoint, client: @client, **options)
    results = []
    streaming(client:).stream(endpoint, **options) { |json| results << json }
    results
  end

  def with_stubbed_stream(chunks:, client: @client, &test_block)
    mock_response = mock_streaming_response(chunks:)
    connection = streaming(client:).instance_variable_get(:@connection)
    connection.stub(:perform_stream, ->(**_, &block) { block.call(mock_response) }, &test_block)
  end

  def with_stream_request(mock_response, client: @client, &test_block)
    captured_request = nil
    connection = streaming(client:).instance_variable_get(:@connection)
    connection.stub(:perform_stream, lambda { |request:, &block|
      captured_request = request
      block.call(mock_response)
    }, &test_block)
    captured_request
  end

  def mock_streaming_response(chunks:)
    response = Minitest::Mock.new
    response.expect(:is_a?, true, [Net::HTTPSuccess])
    response.expect(:read_body, nil) do |&block|
      chunks.each { |chunk| block.call(chunk) }
    end
    response
  end
end
