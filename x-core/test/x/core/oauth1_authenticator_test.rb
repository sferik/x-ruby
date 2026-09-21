# frozen_string_literal: true

require "net/http"
require_relative "../../test_helper"

module X
  class OAuth1AuthenticatorTest < Minitest::Test
    cover OAuth1Authenticator

    def setup
      @authenticator = OAuth1Authenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET,
        access_token: TEST_ACCESS_TOKEN, access_token_secret: TEST_ACCESS_TOKEN_SECRET)
    end

    def test_old_name_is_gone
      refute X.const_defined?(:OAuthAuthenticator)
    end

    def test_inspect_hides_the_secrets
      assert_equal "#<X::OAuth1Authenticator>", @authenticator.inspect
    end

    def test_initialization
      assert_equal TEST_API_KEY, @authenticator.api_key
      assert_equal TEST_ACCESS_TOKEN, @authenticator.access_token
    end

    def test_the_access_token_names_the_user_it_acts_for
      assert_equal 7505382, OAuth1Authenticator.new(**test_oauth_credentials, access_token: "7505382-abc").user_id
    end

    def test_a_token_prefix_is_read_as_decimal_digits
      assert_equal 10, OAuth1Authenticator.new(**test_oauth_credentials, access_token: "010-abc").user_id
    end

    def test_an_access_token_that_names_no_user_has_no_user_id
      ["abc", "-7505382", "7505382", "", nil, "7505382abc", " 7505382-abc"].each do |access_token|
        assert_nil OAuth1Authenticator.new(**test_oauth_credentials, access_token:).user_id
      end
    end

    def test_default_oauth_nonce
      SecureRandom.stub :hex, TEST_OAUTH_NONCE do
        assert_includes authorization_for(get_request), "oauth_nonce=\"#{TEST_OAUTH_NONCE}\""
      end
    end

    def test_default_oauth_timestamp
      Time.stub :now, Time.utc(1983, 11, 24) do
        assert_includes authorization_for(get_request), "oauth_timestamp=\"#{TEST_OAUTH_TIMESTAMP}\""
      end
    end

    def test_header_contains_authorization_key
      header = @authenticator.header(get_request)

      assert header.key?("Authorization"), "Header does not contain \"Authorization\" key"
    end

    def test_header_starts_with_oauth
      assert authorization_for(get_request).start_with?("OAuth ")
    end

    def test_header_contains_required_oauth_fields
      authorization = authorization_for(get_request)

      assert_includes authorization, "oauth_consumer_key=\"#{TEST_API_KEY}\""
      assert_includes authorization, "oauth_token=\"#{TEST_ACCESS_TOKEN}\""
    end

    def test_header_contains_oauth_signature_method
      assert_includes authorization_for(get_request), "oauth_signature_method=\"HMAC-SHA1\""
    end

    def test_header_contains_oauth_version
      assert_includes authorization_for(get_request), "oauth_version=\"1.0\""
    end

    def test_header_in_alphabetical_order
      oauth_keys = authorization_for(get_request).scan(/oauth_[a-z0-9_]+/)

      assert_equal oauth_keys.sort, oauth_keys, "OAuth keys are not sorted in alphabetical order"
    end

    def test_signs_the_query_parameters
      expected = "OAuth oauth_consumer_key=\"TEST_API_KEY\", oauth_nonce=\"TEST_OAUTH_NONCE\", " \
                 "oauth_signature=\"1kHVZMzcNj51v60H63%2FTZErArAk%3D\", oauth_signature_method=\"HMAC-SHA1\", " \
                 "oauth_timestamp=\"438480000\", oauth_token=\"TEST_ACCESS_TOKEN\", oauth_version=\"1.0\""

      with_fixed_oauth_params do
        assert_equal expected, authorization_for(get_request("https://example.com/?query=test"))
      end
    end

    def test_signs_a_query_parameter_that_repeats
      with_fixed_oauth_params do
        repeated = authorization_for(get_request("https://example.com/?id=1&id=2"))
        single = authorization_for(get_request("https://example.com/?id=1"))

        refute_equal single, repeated
      end
    end

    private

    def authorization_for(request)
      @authenticator.header(request)["Authorization"]
    end
  end

  # The worked example X publishes for OAuth 1.0a, which signs a form-encoded body
  # @see https://docs.x.com/resources/fundamentals/authentication/oauth-1-0a/creating-a-signature
  class OAuth1AuthenticatorDocumentedExampleTest < Minitest::Test
    cover OAuth1Authenticator

    NONCE = "kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg"
    TIMESTAMP = 1_318_622_958
    URL = "https://api.twitter.com/1.1/statuses/update.json?include_entities=true"
    BODY = "status=Hello%20Ladies%20%2B%20Gentlemen%2C%20a%20signed%20OAuth%20request%21"
    SIGNATURE = "hCtSmYh%2BiHYCEqBWrE7C7hYmtUk%3D"

    def setup
      @authenticator = OAuth1Authenticator.new(api_key: "xvz1evFS4wEEPTGEFPHBog",
        api_key_secret: "kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw",
        access_token: "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb",
        access_token_secret: "LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE")
    end

    def test_matches_the_signature_x_documents
      with_fixed_oauth_params(nonce: NONCE, time: Time.at(TIMESTAMP)) do
        assert_includes authorization, "oauth_signature=\"#{SIGNATURE}\""
      end
    end

    def test_signs_the_form_encoded_body
      with_fixed_oauth_params(nonce: NONCE, time: Time.at(TIMESTAMP)) do
        without_body = @authenticator.header(post_request(body: nil))["Authorization"]

        refute_equal without_body, authorization
      end
    end

    private

    def authorization
      @authenticator.header(post_request)["Authorization"]
    end

    def post_request(body: BODY, content_type: "application/x-www-form-urlencoded")
      request = Net::HTTP::Post.new(URI(URL))
      request["Content-Type"] = content_type
      request.body = body
      request
    end
  end

  # Only a form-encoded body takes part in the signature
  class OAuth1AuthenticatorBodyTest < Minitest::Test
    cover OAuth1Authenticator

    URL = "https://api.x.com/2/tweets"
    FORM_BODY = "status=Hello"

    def setup
      @authenticator = OAuth1Authenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET,
        access_token: TEST_ACCESS_TOKEN, access_token_secret: TEST_ACCESS_TOKEN_SECRET)
    end

    def test_a_json_body_is_not_signed
      with_fixed_oauth_params do
        assert_equal signature(nil, "application/json; charset=utf-8"),
          signature('{"text":"Hello"}', "application/json; charset=utf-8")
      end
    end

    def test_a_multipart_body_is_not_signed
      with_fixed_oauth_params do
        assert_equal signature(nil, "multipart/form-data; boundary=abc"),
          signature("--abc\r\nstatus=Hello\r\n--abc--", "multipart/form-data; boundary=abc")
      end
    end

    def test_a_form_encoded_body_is_signed
      with_fixed_oauth_params do
        refute_equal signature(nil, "application/x-www-form-urlencoded"),
          signature(FORM_BODY, "application/x-www-form-urlencoded")
      end
    end

    def test_a_form_content_type_with_a_charset_is_signed
      with_fixed_oauth_params do
        assert_equal signature(FORM_BODY, "application/x-www-form-urlencoded"),
          signature(FORM_BODY, "application/x-www-form-urlencoded; charset=utf-8")
      end
    end

    def test_a_form_content_type_in_uppercase_and_padded_is_signed
      with_fixed_oauth_params do
        assert_equal signature(FORM_BODY, "application/x-www-form-urlencoded"),
          signature(FORM_BODY, " Application/X-WWW-Form-Urlencoded ; charset=utf-8")
      end
    end

    def test_a_media_type_that_merely_begins_with_the_form_media_type_is_not_signed
      with_fixed_oauth_params do
        assert_equal signature(nil, "application/x-www-form-urlencoded-json"),
          signature(FORM_BODY, "application/x-www-form-urlencoded-json")
      end
    end

    def test_a_form_encoded_request_without_a_body
      with_fixed_oauth_params do
        assert_equal signature(nil, "application/json"), signature(nil, "application/x-www-form-urlencoded")
      end
    end

    private

    def signature(body, content_type)
      request = Net::HTTP::Post.new(URI(URL))
      request["Content-Type"] = content_type
      request.body = body
      @authenticator.header(request)["Authorization"][/oauth_signature="([^"]+)"/, 1]
    end
  end
end
