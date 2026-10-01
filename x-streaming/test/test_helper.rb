# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

unless $PROGRAM_NAME.include?("mutant")
  require "simplecov"

  SimpleCov.start "strict" do
    # x-core is loaded from its own directory, whose suite covers it
    add_filter "/x-core/"
  end
end

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
require "x/streaming"

X::Client.include(X::Streaming::API)

TEST_BEARER_TOKEN = "TEST_BEARER_TOKEN"
TEST_API_KEY = "TEST_API_KEY"
TEST_API_KEY_SECRET = "TEST_API_KEY_SECRET"
TEST_ACCESS_TOKEN = "TEST_ACCESS_TOKEN"
TEST_ACCESS_TOKEN_SECRET = "TEST_ACCESS_TOKEN_SECRET"
TEST_CLIENT_ID = "TEST_CLIENT_ID"
TEST_CLIENT_SECRET = "TEST_CLIENT_SECRET"
TEST_REFRESH_TOKEN = "TEST_REFRESH_TOKEN"
# The endpoint X exchanges an app's API key and secret for its bearer token at
APP_ONLY_TOKEN_URL = "https://api.x.com/oauth2/token"

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

# Run a stream that reconnects no more to its end, which the server ending it raises for; any other error is raised
def until_the_stream_ends
  yield

  flunk "the stream returned rather than raise once it ended"
rescue X::NetworkError => e
  raise unless e.message.end_with?("The stream ended")
end

# A class that builds objects from a whole response, as the object layer's resources do, accepting the keywords
# later versions of x-core may pass it
class ResponseBuilder
  # Return what it was given, so a test can see the body and the client
  def self.from_response(body, client:, **) = {body:, client:}
end

# Answer one request from a server on the loopback interface, for the requests webmock cannot stand in for
module LocalServer
  # Answer the next request the server accepts with response, on a thread of its own
  def serve_once(server, response)
    Thread.new do
      socket = server.accept
      socket.gets("\r\n\r\n")
      socket.write(response)
      socket.close
    end
  end

  # Serve one HTTP response from a port of the loopback interface, and yield that port with webmock disabled, since
  # webmock reads the body of a stream before the stream does, even with net connections allowed
  def with_local_server(response:)
    server = TCPServer.new("127.0.0.1", 0)
    thread = serve_once(server, response)
    WebMock.disable!
    yield server.addr[1]
  ensure
    WebMock.enable!
    thread&.kill
    server&.close
  end
end

# Stand in for the stream a streaming client opens, delivering chunks of its body, and collect what it yields
module StreamHelpers
  # The streaming client of a client, which reconnects no stream, since a stub delivers its chunks once
  def streaming(client: @client)
    @streaming ||= {}
    @streaming[client] ||= client.streaming(max_reconnects: 0)
  end

  def stream_and_collect(endpoint, client: @client, **options)
    results = []
    until_the_stream_ends { streaming(client:).stream(endpoint, **options) { |json| results << json } }
    results
  end

  # Answer each stream of the streaming client with a response whose body arrives in the chunks given
  def with_stubbed_stream(chunks:, client: @client, &)
    stream_client = streaming(client:).instance_variable_get(:@stream_client)
    stream_client.stub(:get_stream, ->(endpoint, **, &block) { block.call(streaming_response(endpoint, chunks:, client:)) }, &)
  end

  # A successful response of a stream of the client, whose body arrives in the chunks given
  def streaming_response(endpoint, chunks:, client: @client)
    Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
      response.uri = URI.join(client.base_url, endpoint)
      response.define_singleton_method(:read_body) { |&block| chunks.each { |chunk| block.call(chunk) } }
    end
  end
end
