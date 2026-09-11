$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

unless $PROGRAM_NAME.include?("mutant")
  require "simplecov"

  SimpleCov.start "strict"
end

require "minitest/autorun"
require "minitest/mock"
require "mutant/minitest/coverage"
require "webmock/minitest"
require "x"

TEST_BEARER_TOKEN = "TEST_BEARER_TOKEN".freeze
TEST_API_KEY = "TEST_API_KEY".freeze
TEST_API_KEY_SECRET = "TEST_API_KEY_SECRET".freeze
TEST_ACCESS_TOKEN = "TEST_ACCESS_TOKEN".freeze
TEST_ACCESS_TOKEN_SECRET = "TEST_ACCESS_TOKEN_SECRET".freeze
TEST_OAUTH_NONCE = "TEST_OAUTH_NONCE".freeze
TEST_OAUTH_TIMESTAMP = Time.utc(1983, 11, 24).to_i.to_s
TEST_MEDIA_ID = "TEST_MEDIA_ID".freeze
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

def test_oauth_params
  {
    "oauth_consumer_key" => TEST_API_KEY,
    "oauth_nonce" => TEST_OAUTH_NONCE,
    "oauth_signature_method" => X::OAuthAuthenticator::OAUTH_SIGNATURE_METHOD,
    "oauth_timestamp" => TEST_OAUTH_TIMESTAMP,
    "oauth_token" => TEST_ACCESS_TOKEN,
    "oauth_version" => X::OAuthAuthenticator::OAUTH_VERSION
  }
end

# A client double for the object layer that records requests and returns canned responses
class FakeClient
  include X::Objects::API

  # The object layer must always ask for plain hashes and arrays
  JSON_CLASSES = {array_class: Array, object_class: Hash}.freeze

  attr_reader :requests

  def initialize(responses = {})
    @responses = responses
    @requests = []
    @mutex = Mutex.new
  end

  def get(endpoint, **options)
    respond(:get, endpoint, nil, options)
  end

  def post(endpoint, body = nil, **options)
    respond(:post, endpoint, body, options)
  end

  def delete(endpoint, **options)
    respond(:delete, endpoint, nil, options)
  end

  def stub(method, path, response)
    @responses[[method, path]] = response
    self
  end

  def paths
    requests.map { |request| request.fetch(:path) }
  end

  def queries
    requests.map { |request| request.fetch(:query) }
  end

  private

  def respond(method, endpoint, body, options)
    raise ArgumentError, "expected #{JSON_CLASSES} but got #{options}" unless options.eql?(JSON_CLASSES)

    uri = URI.parse(endpoint)
    query = URI.decode_www_form(uri.query.to_s).to_h
    @mutex.synchronize { @requests << {method:, path: uri.path, query:, body:} }
    response = @responses.fetch([method, uri.path]) { raise KeyError, "unstubbed #{method} #{uri.path}" }
    response.respond_to?(:call) ? response.call(query, body) : response
  end
end
