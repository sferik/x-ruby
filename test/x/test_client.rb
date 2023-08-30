require_relative "../test_helper"
require "hashie"

# Tests for X::Client class
class ClientTest < Minitest::Test
  def setup
    @client = client
  end

  # Define test cases for different HTTP methods using parameterized testing
  %i[get post put delete].each do |http_method|
    define_method("test_#{http_method}_request_success") do
      stub_request(http_method, "https://api.twitter.com/2/tweets")
        .with(headers: {"Authorization" => /OAuth/})
        .to_return(status: 200, headers: {"content-type" => "application/json; charset=utf-8"}, body: {}.to_json)

      response = @client.public_send(http_method, "tweets")

      assert_instance_of Hash, response
      assert_requested http_method, "https://api.twitter.com/2/tweets"
    end
  end

  def test_api_key
    assert_equal TEST_API_KEY, @client.api_key
    assert_equal TEST_API_KEY_SECRET, @client.api_key_secret
  end

  def test_set_api_key
    @client.api_key = "abc"
    @client.api_key_secret = "def"

    assert_equal "abc", @client.api_key
    assert_equal "def", @client.api_key_secret
  end

  def test_access_token
    assert_equal TEST_ACCESS_TOKEN, @client.access_token
    assert_equal TEST_ACCESS_TOKEN_SECRET, @client.access_token_secret
  end

  def test_set_access_token
    @client.access_token = "abc"
    @client.access_token_secret = "def"

    assert_equal "abc", @client.access_token
    assert_equal "def", @client.access_token_secret
  end

  def test_default_base_url
    assert_equal URI.parse(X::ClientDefaults::DEFAULT_BASE_URL), @client.base_url
  end

  def test_set_base_url
    url = URI("https://example.com")
    @client.base_url = url

    assert_equal url, @client.base_url
  end

  def test_default_user_agent
    assert_equal X::ClientDefaults::DEFAULT_USER_AGENT, @client.user_agent
  end

  def test_set_user_agent
    @client.user_agent = "Custom User Agent"

    assert_equal "Custom User Agent", @client.user_agent
  end

  def test_default_timeouts
    assert_equal X::ClientDefaults::DEFAULT_OPEN_TIMEOUT, @client.open_timeout
    assert_equal X::ClientDefaults::DEFAULT_READ_TIMEOUT, @client.read_timeout
    assert_equal X::ClientDefaults::DEFAULT_WRITE_TIMEOUT, @client.write_timeout
  end

  def test_set_timeouts
    @client.open_timeout = 10
    @client.read_timeout = 10
    @client.write_timeout = 10

    assert_equal 10, @client.open_timeout
    assert_equal 10, @client.read_timeout
    assert_equal 10, @client.write_timeout
  end

  def test_default_debug_output
    assert_nil @client.debug_output
  end

  def test_set_debug_output
    @client.debug_output = $stderr

    assert_equal $stderr, @client.debug_output
  end

  def test_default_object_class
    assert_equal X::ClientDefaults::DEFAULT_OBJECT_CLASS, @client.object_class
  end

  def test_set_object_class
    @client.object_class = Hashie::Mash

    assert_equal Hashie::Mash, @client.object_class
  end

  def test_default_array_class
    assert_equal X::ClientDefaults::DEFAULT_ARRAY_CLASS, @client.array_class
  end

  def test_set_array_class
    @client.array_class = Set

    assert_equal Set, @client.array_class
  end
end
