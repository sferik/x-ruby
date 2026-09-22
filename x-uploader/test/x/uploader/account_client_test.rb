# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/account"

module X
  class AccountClientTest < Minitest::Test
    cover Uploader::Account

    V1_URL = "https://api.x.com/1.1/account/"
    V1_URL_PATTERN = /\A#{Regexp.escape(V1_URL)}/

    def setup
      @client = Client.new(**test_oauth_credentials)
      stub_request(:post, V1_URL_PATTERN).to_return(status: 200)
    end

    def test_image_upload_uses_a_v1_client_with_the_same_credentials
      Uploader::Account.update_profile_image_binary("image", client: @client)

      assert_requested(:post, "#{V1_URL}update_profile_image.json") { |request| request.headers["Authorization"].include?("oauth_consumer_key=\"#{TEST_API_KEY}\"") }
    end

    def test_banner_upload_uses_a_v1_client_with_the_same_credentials
      Uploader::Account.update_profile_banner_binary("banner", client: @client)

      assert_requested(:post, "#{V1_URL}update_profile_banner.json") { |request| request.headers["Authorization"].include?("oauth_token=\"#{TEST_ACCESS_TOKEN}\"") }
    end

    def test_an_image_upload_posts_to_the_v1_url_with_the_connection_the_client_holds
      performed = performed_by(@client) { Uploader::Account.update_profile_image_binary("image", client: @client) }

      assert_equal ["#{V1_URL}update_profile_image.json"], performed
      assert_equal "https://api.x.com/2/", @client.base_url
    end

    def test_a_banner_upload_posts_to_the_v1_url_with_the_connection_the_client_holds
      performed = performed_by(@client) { Uploader::Account.update_profile_banner_binary("banner", client: @client) }

      assert_equal ["#{V1_URL}update_profile_banner.json"], performed
      assert_equal "https://api.x.com/2/", @client.base_url
    end

    def test_an_upload_copies_the_client_for_nothing
      @client.stub(:with, ->(**) { flunk "the client was copied for an upload" }) do
        Uploader::Account.update_profile_image_binary("image", client: @client)
        Uploader::Account.update_profile_banner_binary("banner", client: @client)
      end

      assert_requested(:post, V1_URL_PATTERN, times: 2)
    end

    def test_an_upload_keeps_the_settings_of_the_client
      client = Client.new(**test_oauth_credentials, read_timeout: 9, max_redirects: 1)
      Uploader::Account.update_profile_image_binary("image", client:)

      assert_requested(:post, "#{V1_URL}update_profile_image.json")
      assert_equal [9, 1, "https://api.x.com/2/"], [client.read_timeout, client.max_redirects, client.base_url]
    end

    def test_missing_file_message
      error = assert_raises(Errno::ENOENT) { Uploader::Account.update_profile_image("nope.png", client: @client) }

      assert_equal "No such file or directory - nope.png", error.message
    end

    def test_unsupported_file_type_message
      error = assert_raises(InvalidMediaType) do
        Uploader::Account.update_profile_banner("test/sample_files/sample.mp4", client: @client)
      end

      assert_equal "Unsupported file type: mp4. Supported types: gif, jpg, jpeg, png", error.message
    end

    def test_extension_is_case_insensitive
      Dir.mktmpdir do |dir|
        path = File.join(dir, "AVATAR.PNG")
        FileUtils.cp("test/sample_files/sample.png", path)
        Uploader::Account.update_profile_image(path, client: @client)
      end

      assert_requested(:post, "#{V1_URL}update_profile_image.json")
    end

    private

    # The URLs of the requests the block performed with the connection the client holds, which a copy would hold none of
    def performed_by(client, &)
      performed = []
      connection = client.instance_variable_get(:@connection)
      perform = connection.method(:perform)
      recorder = lambda do |request:|
        performed << request.uri.to_s
        perform.call(request:)
      end
      connection.stub(:perform, recorder, &)
      performed
    end
  end
end
