$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

unless $PROGRAM_NAME.include?("mutant")
  require "simplecov"

  SimpleCov.start "strict"
end

require "securerandom"
require "socket"
require "minitest/autorun"
require "minitest/mock"
# Mutant is in the bundle of CRuby alone, where the mutant job of CI runs. Without it, the expression a test
# declares it covers is read by nothing, so cover does nothing rather than fail the suite on another engine.
begin
  require "mutant/minitest/coverage"
rescue LoadError
  module Minitest
    class Test
      # Ignore the expression this test covers, which only Mutant reads
      #
      # @param _expression [Object] the expression the test covers
      # @return [void]
      def self.cover(_expression) = nil
    end
  end
end
require "webmock/minitest"
require "x/core"

module Minitest
  class Test
    # Cover X::Client and the modules of x-core that compose it
    #
    # Mutant matches a test to a subject by the expression the test covers, and a method a module mixes into the
    # client is a subject of the module that defines it, so a test of the client names them here rather than one by
    # one.
    #
    # @return [void]
    def self.cover_client
      cover X::Client
      cover X::Core::ClientAppOnly
      cover X::Core::ClientCredentials
      cover X::Core::ClientSettings
      cover X::Core::ClientTokenRefresh
      cover X::Core::RequestEncoding
    end
  end
end

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
# The messages of X::Core::CredentialValidator, which is private about the constants that hold them
TEST_INCOMPLETE_CREDENTIALS = "The credentials given do not form a complete set. Pass api_key, api_key_secret, " \
  "access_token, and access_token_secret for OAuth 1.0a; client_id, access_token, and refresh_token, with the " \
  "client_secret of a confidential client, for OAuth 2.0; bearer_token for a bearer token, such as an OAuth 2.0 " \
  "access token that is not refreshed; or api_key and api_key_secret to authenticate as the app. Leave out any " \
  "credential of a set that is not complete".freeze
TEST_INVALID_EXPIRES_AT = "expires_at must be a Time, such as Time.at(seconds) for a time stored as seconds since " \
  "the epoch, or nil if it is not known".freeze

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

# Answer one request from a server on the loopback interface, for the requests webmock cannot stand in for
module LocalServer
  # A response that says nothing, which a server writes before it closes the connection
  EMPTY_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n".freeze

  # Answer the next request the server accepts with response, on a thread of its own
  def serve_once(server, response)
    Thread.new do
      socket = server.accept
      socket.gets("\r\n\r\n")
      socket.write(response)
      socket.close
    end
  end

  # Serve one HTTP response from a port of the given host, and yield that port with net connections allowed
  def with_local_server(host: "127.0.0.1", response: EMPTY_RESPONSE)
    server = TCPServer.new(host, 0)
    thread = serve_once(server, response)
    WebMock.allow_net_connect!
    yield server.addr[1]
  ensure
    WebMock.disable_net_connect!
    thread&.kill
    server&.close
  end
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
