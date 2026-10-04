# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A client keeps a copy of the base URL and proxy URL it was given, so neither it nor its caller can change them
  class ClientSettingsFrozenTest < Minitest::Test
    cover_client

    def test_the_base_url_a_client_reads_is_frozen_and_its_own
      base_url = +"https://api.x.com/2/"
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url:)
      base_url.replace("https://evil.example/2/")

      assert_equal "https://api.x.com/2/", client.base_url
      assert_predicate client.base_url, :frozen?
      assert_predicate Client.new(base_url: +"https://api.x.com/2").base_url, :frozen?
    end

    def test_a_proxy_url_given_as_a_uri_a_caller_changes_later_leaves_the_proxy_of_a_copy_as_it_was
      uri = URI("http://proxy.example.com:8080")
      client = Client.new(proxy_url: uri)
      uri.host = "elsewhere.example"
      connection = internals(client.with(read_timeout: 1)).instance_variable_get(:@connection)

      assert_equal "proxy.example.com", connection.send(:build_http_client, URI("https://api.x.com/2/")).proxy_address
    end
  end
end
