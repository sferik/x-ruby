# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ReadOnlyAttributesTest < Minitest::Test
    {
      OAuth1Authenticator.new(**test_oauth_credentials) => %i[api_key],
      OAuth2Authenticator.new(**test_oauth2_credentials) => %i[client_id expires_at],
      RateLimit.__send__(:new, type: RateLimit::RATE_LIMIT_TYPE, http_response: Net::HTTPOK.new("1.1", "200", "OK")) => %i[type]
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
