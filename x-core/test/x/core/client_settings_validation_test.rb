# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientSettingsValidationTest < Minitest::Test
    cover_client
    cover Core.const_get(:SettingValidator)
    cover Core.const_get(:RedirectHandler)
    cover Core.const_get(:RateLimitHandler)
    cover Core.const_get(:RetryHandler)

    def message_of(&) = assert_raises(ArgumentError, &).message

    def test_a_count_that_is_not_an_integer_of_at_least_zero_is_refused_when_the_client_is_built
      %i[max_redirects max_rate_limit_retries max_retries].each do |name|
        messages = ["3", nil, 1.0, -1].map { |value| message_of { Client.new(name => value) } }

        assert_equal ['"3"', "nil", "1.0", "-1"].map { |value| "#{name} must be an Integer of at least 0, not #{value}" }, messages
      end
    end

    def test_a_base_url_that_is_not_an_absolute_http_url_is_refused_when_the_client_is_built
      values = ["api.x.com/2/", "ftp://api.x.com/2/", "https://", "https:api.x.com", "https://api x.com/", "", nil, URI("https://api.x.com/2/"),
        "https://api.x.com/2?x=1", "https://api.x.com/2/#top", "https://api.x.com/2/?"]
      messages = values.map { |base_url| message_of { Client.new(base_url:) } }

      assert_equal values.map { |value| "base_url must be an absolute http or https URL with no query or fragment, such as \"https://api.x.com/2/\", not #{value.inspect}" }, messages
      assert_raises(ArgumentError) { Client.new.with(base_url: "api.x.com") }
    end

    def test_a_base_url_that_holds_a_user_or_a_password_is_refused_without_revealing_it
      values = %w[https://user:SECRET@api.x.com/2/ https://SECRET@api.x.com/2/ https://@api.x.com/2/ http://user:SECRET@localhost:3000/2/]
      messages = values.map { |base_url| message_of { Client.new(base_url:) } }

      assert_equal ["base_url must hold no user or password, which no request sends"] * values.size, messages
      assert_equal messages.first, message_of { Client.new(base_url: Class.new(String).new(values.first)) }
      assert_raises(ArgumentError) { Client.new.with(base_url: "https://user:SECRET@api.x.com/2/") }
    end

    def test_a_base_url_with_an_at_sign_after_its_host_is_not_read_as_holding_a_user
      assert_equal "https://api.x.com/2/@x/", Client.new(base_url: "https://api.x.com/2/@x/").base_url
      %w[api.x.com/@x //user@api.x.com/2/ https://api.x.com/2/?at=@x https://api.x.com/2/#@x].each do |base_url|
        assert_includes message_of { Client.new(base_url:) }, "not #{base_url.inspect}"
      end
    end

    def test_a_base_url_that_is_an_absolute_http_or_https_url_is_allowed
      assert_equal %w[https://api.x.com/1.1/ http://localhost:3000/2/], %w[https://api.x.com/1.1/ http://localhost:3000/2].map { |base_url| Client.new(base_url:).base_url }
      assert_equal "https://api.x.com/2/", Client.new(base_url: Class.new(String).new("https://api.x.com/2/")).base_url
    end

    def test_headers_that_are_not_a_hash_are_refused_without_revealing_them
      assert_equal "headers must be a Hash of header names to values, not a NilClass", message_of { Client.new(headers: nil) }
      assert_equal "headers must be a Hash of header names to values, not a Array", message_of { Client.new(headers: [%w[Authorization SECRET]]) }
    end

    def test_a_header_whose_name_or_value_is_not_what_a_header_takes_is_refused_without_revealing_its_value
      assert_equal "headers must name each header with a String or a Symbol and give it a String, not \"X-Count\" with a Integer", message_of { Client.new(headers: {"X-Count" => 1}) }
      assert_equal "headers must name each header with a String or a Symbol and give it a String, not :authorization with a NilClass", message_of { Client.new(headers: {authorization: nil}) }
      assert_equal "headers must name each header with a String or a Symbol and give it a String, not a Integer with a String", message_of { Client.new(headers: {1 => "SECRET"}) }
      assert_raises(ArgumentError) { Client.new.with(headers: {"X-Count" => 1}) }
    end

    def test_headers_named_by_a_string_or_a_symbol_are_allowed
      assert_equal({"User-Agent" => "MyApp/1.0"}, Client.new(headers: {"User-Agent" => "MyApp/1.0"}).headers)
      assert_equal({"accept" => "application/json"}, Client.new(headers: {accept: "application/json"}).headers)
    end

    def test_headers_named_by_a_symbol_are_read_by_a_string
      client = Client.new(headers: {"User-Agent": "MyApp/1.0", "X-Trace": "abc"})

      assert_equal "MyApp/1.0", client.headers["User-Agent"]
      assert_equal({"User-Agent" => "MyApp/1.0", "X-Trace" => "abc"}, client.with(max_redirects: 1).headers)
      assert_predicate client.headers, :frozen?
    end

    def test_a_header_of_the_client_named_by_a_symbol_is_read_by_the_name_it_is_sent_with
      assert_equal({"user-agent" => "my-app/1.0", "x-trace" => "abc"}, Client.new(headers: {user_agent: "my-app/1.0", x_trace: "abc"}).headers)
    end

    def test_a_header_named_by_a_string_keeps_its_underscores
      assert_equal({"X_Trace" => "abc"}, Client.new(headers: {"X_Trace" => "abc"}).headers)
    end

    def test_headers_of_subclasses_of_hash_and_string_are_allowed
      assert_equal({"Accept" => "application/json"}, Client.new(headers: {Class.new(String).new("Accept") => "application/json"}).headers)
      assert_equal({"Accept" => "application/json"}, Client.new(headers: Class.new(Hash).new.merge!("Accept" => Class.new(String).new("application/json"))).headers)
    end

    def test_a_count_of_zero_is_allowed
      client = Client.new(max_redirects: 0, max_rate_limit_retries: 0, max_retries: 0)

      assert_equal [0, 0, 0], [client.max_redirects, client.max_rate_limit_retries, client.max_retries]
    end

    def test_a_wait_that_is_not_a_number_of_seconds_of_at_least_zero_is_refused
      messages = ["900", nil, -1, Float::NAN, Complex(1, 0)].map { |value| message_of { Client.new(max_rate_limit_wait: value) } }

      assert_equal ['"900"', "nil", "-1", "NaN", "(1+0i)"].map { |value| "max_rate_limit_wait must be a number of seconds of at least 0, not #{value}" }, messages
    end

    def test_a_wait_of_any_real_number_of_seconds_of_at_least_zero_is_allowed
      assert_equal [0, 1.5, Float::INFINITY], [0, 1.5, Float::INFINITY].map { |value| Client.new(max_rate_limit_wait: value).max_rate_limit_wait }
    end

    def test_a_copy_checks_the_settings_it_is_given
      assert_equal 'max_retries must be an Integer of at least 0, not "1"', message_of { Client.new.with(max_retries: "1") }
    end

    def test_hooks_that_do_not_respond_to_call_are_refused_without_revealing_them
      messages = %i[on_response save_tokens].map { |name| message_of { Client.new(name => "SECRET") } }

      assert_equal %w[on_response save_tokens].map { |name| "#{name} must respond to call, as a Proc or a lambda does, or be nil, not a String" }, messages
      assert_raises(ArgumentError) { Client.new.with(on_response: :log) }
    end

    def test_hooks_that_respond_to_call_are_kept
      on_response = ->(_) {}
      save_tokens = Object.new.tap { |hook| hook.define_singleton_method(:call) { |_| nil } }
      client = Client.new(on_response:, save_tokens:)

      assert_equal [on_response, save_tokens], [client.on_response, client.save_tokens]
    end

    def test_the_validator_returns_what_it_checked
      validator = Core.const_get(:SettingValidator)

      assert_equal [2, 900], [validator.count!(:max_retries, 2), validator.seconds!(:max_rate_limit_wait, 900)]
      refute_respond_to validator, :count?
    end
  end
end
