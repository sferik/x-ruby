# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class RedirectHandlerTest < Minitest::Test
    cover Core::RedirectHandler

    def setup
      @connection = Connection.new
      @request_builder = Core::RequestBuilder.new
      @redirect_handler = Core::RedirectHandler.new(connection: @connection, request_builder: @request_builder)
    end

    def redirect_to(location)
      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["Location"] = location
      response
    end

    def test_initialize_with_defaults
      redirect_handler = Core::RedirectHandler.new

      assert_instance_of Connection, redirect_handler.connection
      assert_instance_of Core::RequestBuilder, redirect_handler.request_builder
    end

    def test_handle_with_no_redirects
      request = Net::HTTP::Get.new(URI("http://example.com/some_path"))

      response = Net::HTTPSuccess.new("1.1", "200", "OK")

      assert_equal(response, @redirect_handler.handle(response:, request:))
    end

    def test_handle_with_one_redirect
      authenticator = BearerTokenAuthenticator.new(bearer_token: TEST_BEARER_TOKEN)
      request = Net::HTTP::Get.new(URI("http://example.com/"))
      stub_request(:get, "http://example.com/2").with(headers: {"Authorization" => /Bearer #{TEST_BEARER_TOKEN}/o})

      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["Location"] = "http://example.com/2"

      @redirect_handler.handle(response:, request:, authenticator:)

      assert_requested :get, "http://example.com/2"
    end

    def test_handle_with_two_redirects
      request = Net::HTTP::Delete.new(URI("http://example.com/"))
      stub_request(:delete, "http://example.com/2").to_return(status: 307, headers: {"Location" => "http://example.com/3"})
      stub_request(:delete, "http://example.com/3")

      response = Net::HTTPFound.new("1.1", "307", "Found")
      response["Location"] = "http://example.com/2"

      @redirect_handler.handle(response:, request:)

      assert_requested :delete, "http://example.com/2"
      assert_requested :delete, "http://example.com/3"
    end

    def test_handle_preserves_authentication_across_redirects
      authenticator = BearerTokenAuthenticator.new(bearer_token: TEST_BEARER_TOKEN)
      authorization = {"Authorization" => /Bearer #{TEST_BEARER_TOKEN}/o}
      stub_request(:get, "http://example.com/2")
        .with(headers: authorization)
        .to_return(status: 302, headers: {"Location" => "http://example.com/3"})
      stub_request(:get, "http://example.com/3").with(headers: authorization)

      @redirect_handler.handle(response: redirect_to("http://example.com/2"), request: Net::HTTP::Get.new(URI("http://example.com/")), authenticator:)

      assert_requested :get, "http://example.com/3", headers: authorization
    end

    def test_handle_with_relative_url
      request = Net::HTTP::Get.new(URI("http://example.com/some_path"))
      stub_request(:get, "http://example.com/some_relative_path")

      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["Location"] = "/some_relative_path"

      @redirect_handler.handle(response:, request:)

      assert_requested :get, "http://example.com/some_relative_path"
    end

    def test_handle_preserves_custom_headers_across_redirects
      headers = {"X-Custom" => "value"}
      stub_request(:get, "http://example.com/2")
        .with(headers:)
        .to_return(status: 302, headers: {"Location" => "http://example.com/3"})
      stub_request(:get, "http://example.com/3").with(headers:)

      @redirect_handler.handle(response: redirect_to("http://example.com/2"), request: Net::HTTP::Get.new(URI("http://example.com/")), headers:)

      assert_requested :get, "http://example.com/3", headers:
    end

    def test_handle_with_too_many_redirects
      request = Net::HTTP::Get.new(URI("http://example.com/some_path"))
      stub_request(:get, "http://example.com/some_path").to_return(status: 302, headers: {"Location" => "http://example.com/some_path"})

      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["Location"] = "http://example.com/some_path"

      e = assert_raises(TooManyRedirects) do
        @redirect_handler.handle(response:, request:)
      end

      assert_equal "Too many redirects", e.message
      assert_requested :get, "http://example.com/some_path", times: Core::RedirectHandler::DEFAULT_MAX_REDIRECTS
    end

    def test_a_max_redirects_of_zero_follows_no_redirect
      handler = Core::RedirectHandler.new(max_redirects: 0)

      assert_raises(TooManyRedirects) { handler.handle(response: redirect_to("http://example.com/2"), request: Net::HTTP::Get.new(URI("http://example.com/"))) }
      assert_not_requested :get, "http://example.com/2"
    end

    def test_a_redirect_that_cannot_be_followed_is_returned_however_many_were_followed
      not_modified = Net::HTTPNotModified.new("1.1", "304", "Not Modified")
      handler = Core::RedirectHandler.new(max_redirects: 0)

      assert_same not_modified, handler.handle(response: not_modified, request: Net::HTTP::Get.new(URI("http://example.com/")))
    end

    def test_handle_beyond_max_redirects
      request = Net::HTTP::Get.new(URI("http://example.com/some_path"))
      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["Location"] = "http://example.com/some_path"
      redirect_count = Core::RedirectHandler::DEFAULT_MAX_REDIRECTS + 1

      assert_raises(TooManyRedirects) do
        @redirect_handler.handle(response:, request:, redirect_count:)
      end
      assert_not_requested :get, "http://example.com/some_path"
    end
  end

  class RedirectHandlerCredentialsTest < Minitest::Test
    cover Core::RedirectHandler
    cover Core::Origin

    AUTHORIZATION = "Bearer #{TEST_BEARER_TOKEN}".freeze

    def setup
      @redirect_handler = Core::RedirectHandler.new
      @authenticator = BearerTokenAuthenticator.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def redirect(from, to, headers: {})
      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["Location"] = to
      @redirect_handler.handle(response:, request: Net::HTTP::Get.new(URI(from)), headers:,
        authenticator: @authenticator)
    end

    def authorizations_sent_to(url)
      WebMock::RequestRegistry.instance.requested_signatures.hash.keys
        .select { |signature| signature.uri.to_s.eql?(url) }.map { |signature| signature.headers.to_h["Authorization"] }
    end

    def test_keeps_credentials_on_the_same_origin
      stub_request(:get, "https://api.x.com:443/2/next")
      redirect("https://api.x.com/2/users", "https://API.x.com/2/next")

      assert_equal [AUTHORIZATION], authorizations_sent_to("https://api.x.com:443/2/next")
    end

    def test_drops_credentials_on_another_host
      stub_request(:get, "https://example.com:443/steal")
      redirect("https://api.x.com/2/users", "https://example.com/steal")

      assert_equal [nil], authorizations_sent_to("https://example.com:443/steal")
    end

    def test_drops_credentials_on_another_scheme
      stub_request(:get, "http://api.x.com:443/2/next")
      redirect("https://api.x.com/2/users", "http://api.x.com:443/2/next")

      assert_equal [nil], authorizations_sent_to("http://api.x.com:443/2/next")
    end

    def test_drops_credentials_on_another_port
      stub_request(:get, "https://api.x.com:8443/2/next")
      redirect("https://api.x.com/2/users", "https://api.x.com:8443/2/next")

      assert_equal [nil], authorizations_sent_to("https://api.x.com:8443/2/next")
    end

    def test_drops_an_authorization_header_on_another_host
      stub_request(:get, "https://example.com:443/steal")
      redirect("https://api.x.com/2/users", "https://example.com/steal", headers: {"authorization" => "Basic secret", "X-Custom" => "kept"})

      assert_requested :get, "https://example.com/steal", headers: {"X-Custom" => "kept"}
      assert_equal [nil], authorizations_sent_to("https://example.com:443/steal")
    end

    def headers_sent_to(url)
      WebMock::RequestRegistry.instance.requested_signatures.hash.keys
        .select { |signature| signature.uri.to_s.eql?(url) }.map { |signature| signature.headers.to_h }
    end

    def test_drops_every_header_that_carries_credentials_on_another_host
      stub_request(:get, "https://example.com:443/steal")
      redirect("https://api.x.com/2/users", "https://example.com/steal",
        headers: {"cookie" => "session=secret", "Authorization" => "Basic secret", "Proxy-Authorization" => "Basic proxy", "X-Custom" => "kept"})

      headers = headers_sent_to("https://example.com:443/steal").fetch(0)

      assert_equal ["kept", nil, nil, nil], headers.values_at("X-Custom", "Authorization", "Cookie", "Proxy-Authorization")
    end

    def test_keeps_every_header_that_carries_credentials_on_the_same_origin
      stub_request(:get, "https://api.x.com:443/2/next")
      redirect("https://api.x.com/2/users", "https://api.x.com/2/next",
        headers: {"Cookie" => "session=secret", "Proxy-Authorization" => "Basic proxy"})

      assert_requested :get, "https://api.x.com/2/next", headers: {"Cookie" => "session=secret", "Proxy-Authorization" => "Basic proxy"}
    end

    def test_drops_an_authorization_header_named_by_a_symbol_on_another_host
      stub_request(:get, "https://example.com:443/steal")
      redirect("https://api.x.com/2/users", "https://example.com/steal", headers: {Authorization: "Bearer secret"})

      assert_equal [nil], authorizations_sent_to("https://example.com:443/steal")
    end

    def test_keeps_credentials_dropped_after_a_redirect_back
      stub_request(:get, "https://example.com:443/back").to_return(status: 302, headers: {"Location" => "https://api.x.com/2/users"})
      stub_request(:get, "https://api.x.com:443/2/users")
      redirect("https://api.x.com/2/users", "https://example.com/back")

      assert_equal [nil], authorizations_sent_to("https://api.x.com:443/2/users")
    end

    def test_compares_origins_with_the_request
      stub_request(:get, "https://upload.x.com:443/next")
      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["Location"] = "https://upload.x.com/next"
      @redirect_handler.handle(response:, request: Net::HTTP::Get.new(URI("https://upload.x.com/media")), authenticator: @authenticator)

      assert_equal [AUTHORIZATION], authorizations_sent_to("https://upload.x.com:443/next")
    end

    def test_resolves_a_relative_location_against_the_host_of_the_request
      stub_request(:get, "https://upload.x.com:443/2/media/next")
      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["Location"] = "next"
      @redirect_handler.handle(response:, request: Net::HTTP::Get.new(URI("https://upload.x.com/2/media/upload")), authenticator: @authenticator)

      assert_equal [AUTHORIZATION], authorizations_sent_to("https://upload.x.com:443/2/media/next")
    end

    def test_resolves_a_relative_location_against_the_path_of_the_request
      stub_request(:get, "https://api.x.com:443/2/users/next")
      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["Location"] = "next"
      @redirect_handler.handle(response:, request: Net::HTTP::Get.new(URI("https://api.x.com/2/users/me")), authenticator: @authenticator)

      assert_equal [AUTHORIZATION], authorizations_sent_to("https://api.x.com:443/2/users/next")
    end
  end

  class RedirectHandlerStatusTest < Minitest::Test
    cover Core::RedirectHandler

    def setup
      @connection = Connection.new
      @request_builder = Core::RequestBuilder.new
      @redirect_handler = Core::RedirectHandler.new(connection: @connection, request_builder: @request_builder)
    end

    def test_handle_with_301_moved_permanently
      request = Net::HTTP::Get.new(URI("http://example.com/some_path"))
      stub_request(:get, "http://example.com/new_path")

      response = Net::HTTPMovedPermanently.new("1.1", "301", "Moved Permanently")
      response["Location"] = "http://example.com/new_path"

      @redirect_handler.handle(response:, request:)

      assert_requested :get, "http://example.com/new_path"
    end

    def test_handle_with_302_found
      request = Net::HTTP::Get.new(URI("http://example.com/some_path"))
      stub_request(:get, "http://example.com/temp_path")

      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["Location"] = "http://example.com/temp_path"

      @redirect_handler.handle(response:, request:)

      assert_requested :get, "http://example.com/temp_path"
    end

    def test_handle_with_303_see_other
      request = Net::HTTP::Post.new(URI("http://example.com/some_path"))
      stub_request(:post, "http://example.com/some_path")
      stub_request(:get, "http://example.com/other_path")

      response = Net::HTTPSeeOther.new("1.1", "303", "See Other")
      response["Location"] = "http://example.com/other_path"

      @redirect_handler.handle(response:, request:)

      assert_requested :get, "http://example.com/other_path"
    end

    def test_handle_with_307_temporary_redirect
      request = Net::HTTP::Post.new(URI("http://example.com/some_path"))
      request.body = "request_body"
      stub_request(:post, "http://example.com/temp_path")

      response = Net::HTTPTemporaryRedirect.new("1.1", "307", "Temporary Redirect")
      response["Location"] = "http://example.com/temp_path"

      @redirect_handler.handle(response:, request:)

      assert_requested :post, "http://example.com/temp_path", body: "request_body"
    end

    def test_handle_with_308_permanent_redirect
      request = Net::HTTP::Post.new(URI("http://example.com/some_path"))
      request.body = "request_body"
      stub_request(:post, "http://example.com/new_path")

      response = Net::HTTPPermanentRedirect.new("1.1", "308", "Permanent Redirect")
      response["Location"] = "http://example.com/new_path"

      @redirect_handler.handle(response:, request:)

      assert_requested :post, "http://example.com/new_path", body: "request_body"
    end
  end
end
