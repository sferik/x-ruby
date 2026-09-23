# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/account"

module X
  # The API v1.1 is reached at the host the client sends its other requests to, which its credentials are sent to
  class AccountOriginTest < Minitest::Test
    cover Uploader::Account

    CONTENT = "image data"
    BEARER_TOKEN = "TEST_BEARER_TOKEN"

    def test_the_profile_image_is_updated_at_the_host_of_the_base_url_with_the_credentials_of_the_client
      stub_request(:post, "https://api.twitter.com/1.1/account/update_profile_image.json")
      client = Client.new(bearer_token: BEARER_TOKEN, base_url: "https://api.twitter.com/2/")
      Uploader::Account.update_profile_image_binary(CONTENT, client:)

      assert_requested(:post, "https://api.twitter.com/1.1/account/update_profile_image.json",
        headers: {"Authorization" => "Bearer #{BEARER_TOKEN}"})
    end

    def test_the_profile_banner_is_updated_beside_the_version_a_proxy_serves
      stub_request(:post, "https://proxy.example.com/x/1.1/account/update_profile_banner.json")
      client = Client.new(bearer_token: BEARER_TOKEN, base_url: "https://proxy.example.com/x/2/")
      Uploader::Account.update_profile_banner_binary(CONTENT, client:)

      assert_requested(:post, "https://proxy.example.com/x/1.1/account/update_profile_banner.json",
        headers: {"Authorization" => "Bearer #{BEARER_TOKEN}"})
    end

    def test_a_client_of_the_api_v1_1_updates_the_profile_image_there
      stub_request(:post, "https://api.x.com/1.1/account/update_profile_image.json")
      Uploader::Account.update_profile_image_binary(CONTENT, client: Client.new(bearer_token: BEARER_TOKEN, base_url: "https://api.x.com/1.1/"))

      assert_requested(:post, "https://api.x.com/1.1/account/update_profile_image.json")
    end
  end
end
