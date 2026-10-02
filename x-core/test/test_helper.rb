# frozen_string_literal: true

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
    # Cover X::Client, its internals, and the modules of x-core that compose them
    #
    # Mutant matches a test to a subject by the expression the test covers, and a method a module mixes into the
    # internals of the client is a subject of the module that defines it, so a test of the client names them here
    # rather than one by one.
    #
    # @return [void]
    def self.cover_client
      cover X::Client
      cover X::Core.const_get(:ClientInternals)
      cover X::Core.const_get(:ClientAppOnly)
      cover X::Core.const_get(:ClientCredentials)
      cover X::Core.const_get(:ClientSettings)
      cover X::Core.const_get(:ClientTokenRefresh)
      cover X::Core.const_get(:RequestEncoding)
    end

    # The internals of a client, which hold its credentials, settings, connection, and handlers
    #
    # @param client [X::Client] the client
    # @return [Object] the internals the client delegates to
    def internals(client) = client.instance_variable_get(:@internals)
  end
end

TEST_BEARER_TOKEN = "TEST_BEARER_TOKEN"
TEST_API_KEY = "TEST_API_KEY"
TEST_API_KEY_SECRET = "TEST_API_KEY_SECRET"
TEST_ACCESS_TOKEN = "TEST_ACCESS_TOKEN"
TEST_ACCESS_TOKEN_SECRET = "TEST_ACCESS_TOKEN_SECRET"
TEST_OAUTH_NONCE = "TEST_OAUTH_NONCE"
TEST_OAUTH_TIMESTAMP = Time.utc(1983, 11, 24).to_i.to_s
TEST_CLIENT_ID = "TEST_CLIENT_ID"
TEST_CLIENT_SECRET = "TEST_CLIENT_SECRET"
TEST_REFRESH_TOKEN = "TEST_REFRESH_TOKEN"
# The endpoints X exchanges credentials for tokens at, which the authenticators and the authorization name privately
APP_ONLY_TOKEN_URL = "https://api.x.com/oauth2/token"
OAUTH2_TOKEN_URL = "https://api.x.com/2/oauth2/token"
# The messages of X::Core.const_get(:CredentialValidator), which is private about the constants that hold them
TEST_INCOMPLETE_CREDENTIALS = "The credentials given do not form a complete set. Pass api_key, api_key_secret, " \
  "access_token, and access_token_secret for OAuth 1.0a; client_id and access_token, with the refresh_token that " \
  "refreshes it and the client_secret of a confidential client, for OAuth 2.0; bearer_token for the app's bearer " \
  "token; or api_key and api_key_secret to authenticate as the app. Leave out any credential of a set that is not " \
  "complete"
TEST_UNUSED_EXPIRES_AT = "expires_at is the time an OAuth 2.0 access token expires, so it is given beside the " \
  "client_id and access_token the client authenticates with, rather than beside OAuth 1.0a credentials, a " \
  "bearer_token, an api_key and api_key_secret, or none, which would leave it unused. Leave it out"
TEST_INVALID_EXPIRES_AT = "expires_at must be a Time, such as Time.at(seconds) for a time stored as seconds since " \
  "the epoch, or nil if it is not known"

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

# An OAuth 2.0 authenticator that reports its refreshes to hooks, as the authenticator a client builds reports them
def oauth2_authenticator_reporting_to(*hooks, **options)
  X::OAuth2Authenticator.new(**test_oauth2_credentials, **options).tap do |authenticator|
    authenticator.__send__(:report_refreshes_to, -> { hooks })
  end
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

# A class that builds objects from a whole response, as the object layer's resources do, accepting the keywords
# later versions of x-core may pass it
class ResponseBuilder
  # Return what it was given, so a test can see the body and the client
  def self.from_response(body, client:, **) = {body:, client:}
end

# Answer one request from a server on the loopback interface, for the requests webmock cannot stand in for
module LocalServer
  # A response that says nothing, which a server writes before it closes the connection
  EMPTY_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"

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

  # Answer each connection the server accepts with the responses listed for it, a request each, in turn, and close it
  # after the last, on a thread of its own, adding each request it reads to requests
  def serve_connections(server, connections, requests)
    Thread.new do
      connections.each do |responses|
        socket = server.accept
        responses.each { |response| socket.write(response) if requests << socket.gets("\r\n\r\n") }
        socket.close
      end
    end
  end

  # Serve connections from a port of the loopback interface, with webmock disabled, as Net::HTTP reads them, and yield
  # that port and the requests the server read, which a test counts
  def with_local_connections(*connections)
    server = TCPServer.new("127.0.0.1", 0)
    requests = []
    thread = serve_connections(server, connections, requests)
    WebMock.disable!
    yield server.addr[1], requests
  ensure
    WebMock.enable!
    thread&.kill
    server&.close
  end
end
