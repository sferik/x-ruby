# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientRedirectContentTypeTest < Minitest::Test
    cover_client
    cover Core.const_get(:RedirectHandler)

    FORM_CONTENT_TYPE = "application/x-www-form-urlencoded; charset=utf-8"

    def setup
      @client = Client.new
    end

    def redirect(status, from, to, method: :post)
      stub_request(method, "https://api.x.com/2/#{from}").to_return(status:, headers: {"Location" => "https://api.x.com/2/#{to}"})
    end

    def assert_requested_without_content_type(method, url)
      assert_requested(method, url) { |request| request.body.to_s.empty? && request.headers.keys.none? { |name| name.casecmp?("Content-Type") } }
    end

    def test_a_form_post_redirected_to_a_get_sends_no_content_type
      [301, 302, 303].each do |status|
        redirect(status, "old#{status}", "new#{status}")
        stub_request(:get, "https://api.x.com/2/new#{status}")
        @client.post("old#{status}", form: {lang: "en"})

        assert_requested_without_content_type :get, "https://api.x.com/2/new#{status}"
      end
    end

    def test_a_json_post_redirected_to_a_get_sends_no_content_type
      redirect(303, "old", "new")
      stub_request(:get, "https://api.x.com/2/new")
      @client.post("old", {text: "Hello"})

      assert_requested_without_content_type :get, "https://api.x.com/2/new"
    end

    def test_a_content_type_of_the_caller_is_dropped_whatever_its_case
      redirect(303, "old", "new")
      stub_request(:get, "https://api.x.com/2/new")
      @client.post("old", "lang=en", headers: {"content-type" => "text/plain"})

      assert_requested_without_content_type :get, "https://api.x.com/2/new"
    end

    def test_a_content_type_of_the_caller_named_by_a_symbol_is_dropped
      redirect(303, "old", "new")
      stub_request(:get, "https://api.x.com/2/new")
      @client.post("old", "lang=en", headers: {"Content-Type": "text/plain"})

      assert_requested_without_content_type :get, "https://api.x.com/2/new"
    end

    def test_a_form_post_redirected_with_308_keeps_its_content_type
      redirect(308, "old", "new")
      stub_request(:post, "https://api.x.com/2/new")
      @client.post("old", form: {lang: "en"})

      assert_requested :post, "https://api.x.com/2/new", body: "lang=en", headers: {"Content-Type" => FORM_CONTENT_TYPE}
    end

    def test_a_get_redirected_again_with_307_sends_no_content_type
      redirect(303, "old", "middle")
      redirect(307, "middle", "new", method: :get)
      stub_request(:get, "https://api.x.com/2/new")
      @client.post("old", form: {lang: "en"})

      assert_requested_without_content_type :get, "https://api.x.com/2/new"
    end
  end
end
