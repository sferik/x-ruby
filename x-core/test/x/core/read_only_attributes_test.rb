require_relative "../../test_helper"

module X
  class ReadOnlyAttributesTest < Minitest::Test
    {
      BearerTokenAuthenticator.new(bearer_token: TEST_BEARER_TOKEN) => %i[bearer_token],
      OAuth1Authenticator.new(**test_oauth_credentials) => %i[api_key api_key_secret access_token access_token_secret],
      OAuth2Authenticator.new(**test_oauth2_credentials) => %i[client_id client_secret access_token refresh_token expires_at connection on_refresh],
      RateLimit.new(type: RateLimit::RATE_LIMIT_TYPE, response: Net::HTTPOK.new("1.1", "200", "OK")) => %i[type response]
    }.each do |object, attributes|
      attributes.each do |attribute|
        define_method(:"test_#{object.class.name.split("::").last.downcase}_#{attribute}_is_read_only") do
          assert_respond_to object, attribute
          refute_respond_to object, :"#{attribute}="
        end
      end
    end
  end
end
