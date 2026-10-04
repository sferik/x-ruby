# frozen_string_literal: true

require "net/http"
require "uri"
require_relative "../../test_helper"

module X
  # A proxy URL must name a host, which Net::HTTP would otherwise take for no proxy, and is parsed anew, so that a URI
  # its caller changes later changes no proxy
  class ConnectionProxyUrlTest < Minitest::Test
    cover Core.const_get(:Connection)
    cover Core.const_get(:ConnectionProxy)

    def test_a_proxy_url_that_names_no_host_is_refused
      ["http:proxy.example.com:8080", "http:/proxy:8080", "https:proxy:8080", URI("http:proxy:8080")].each do |url|
        assert_raises(ArgumentError, url.to_s) { Core.const_get(:Connection).new(proxy_url: url) }
      end
    end

    def test_a_proxy_url_given_as_a_uri_is_copied_so_a_later_change_to_it_changes_no_proxy
      uri = URI("http://example.com:8080")
      connection = Core.const_get(:Connection).new(proxy_url: uri)
      uri.port = 9090

      assert_equal 8080, connection.send(:build_http_client, URI("https://api.x.com/2/tweets")).proxy_port
    end
  end
end
