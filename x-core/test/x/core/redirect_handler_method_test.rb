# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class RedirectHandlerMethodTest < Minitest::Test
    cover Core.const_get(:RedirectHandler)

    def setup
      @redirect_handler = Core.const_get(:RedirectHandler).new
    end

    def redirect_to(location)
      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["Location"] = location
      response
    end

    def test_a_moved_redirect_keeps_the_method_and_the_body_of_a_put_or_a_delete
      [[Net::HTTP::Put, :put, "301"], [Net::HTTP::Delete, :delete, "302"]].each do |request_class, method, code|
        request = request_class.new(URI("http://example.com/#{method}"))
        request.body = "{}"
        stub_request(method, "http://example.com/#{method}/2")
        response = Net::HTTPRedirection.new("1.1", code, "Moved")
        response["Location"] = "http://example.com/#{method}/2"

        @redirect_handler.handle(response:, request:, headers: {"Content-Type" => "application/json"})

        assert_requested method, "http://example.com/#{method}/2", body: "{}", headers: {"Content-Type" => "application/json"}
      end
    end

    def test_a_moved_redirect_follows_a_post_with_a_get
      request = Net::HTTP::Post.new(URI("http://example.com/"))
      request.body = "{}"
      stub_request(:get, "http://example.com/2")

      @redirect_handler.handle(response: redirect_to("http://example.com/2"), request:)

      assert_requested(:get, "http://example.com/2") { |redirected| redirected.body.to_s.empty? }
    end

    def test_a_see_other_redirect_follows_a_delete_with_a_get
      request = Net::HTTP::Delete.new(URI("http://example.com/"))
      stub_request(:get, "http://example.com/2")
      response = Net::HTTPSeeOther.new("1.1", "303", "See Other")
      response["Location"] = "http://example.com/2"

      @redirect_handler.handle(response:, request:, headers: {"X-Custom" => "value"})

      assert_requested :get, "http://example.com/2", headers: {"X-Custom" => "value"}
    end

    def test_follow_with_no_redirects_returns_the_response_and_its_request
      request = Net::HTTP::Get.new(URI("http://example.com/some_path"))
      response = Net::HTTPSuccess.new("1.1", "200", "OK")

      assert_equal [response, request], @redirect_handler.follow(response:, request:)
    end

    def test_follow_returns_the_request_the_final_response_answers
      request = Net::HTTP::Post.new(URI("http://example.com/old"))
      response = Net::HTTPSeeOther.new("1.1", "303", "See Other")
      response["Location"] = "http://example.com/new"
      stub_request(:get, "http://example.com/new")
      final_response, final_request = @redirect_handler.follow(response:, request:)

      assert_equal ["200", "GET", "http://example.com/new"], [final_response.code, final_request.method, final_request.uri.to_s]
    end
  end
end
