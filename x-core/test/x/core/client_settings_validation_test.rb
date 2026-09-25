# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientSettingsValidationTest < Minitest::Test
    cover_client
    cover Core::SettingValidator
    cover Core::RedirectHandler
    cover Core::RateLimitHandler
    cover Core::RetryHandler
    cover Core::ReconnectHandler

    def message_of(&) = assert_raises(ArgumentError, &).message

    def test_a_count_that_is_not_an_integer_of_at_least_zero_is_refused_when_the_client_is_built
      %i[max_redirects max_rate_limit_retries max_retries].each do |name|
        messages = ["3", nil, 1.0, -1].map { |value| message_of { Client.new(name => value) } }

        assert_equal ['"3"', "nil", "1.0", "-1"].map { |value| "#{name} must be an Integer of at least 0, not #{value}" }, messages
      end
    end

    def test_a_count_of_zero_is_allowed
      client = Client.new(max_redirects: 0, max_rate_limit_retries: 0, max_retries: 0)

      assert_equal [0, 0, 0], [client.max_redirects, client.max_rate_limit_retries, client.max_retries]
    end

    def test_a_wait_that_is_not_a_number_of_seconds_of_at_least_zero_is_refused
      messages = ["900", nil, -1, Complex(1, 0)].map { |value| message_of { Client.new(max_rate_limit_wait: value) } }

      assert_equal ['"900"', "nil", "-1", "(1+0i)"].map { |value| "max_rate_limit_wait must be a number of seconds of at least 0, not #{value}" }, messages
    end

    def test_a_wait_of_any_real_number_of_seconds_of_at_least_zero_is_allowed
      assert_equal [0, 1.5, Float::INFINITY], [0, 1.5, Float::INFINITY].map { |value| Client.new(max_rate_limit_wait: value).max_rate_limit_wait }
    end

    def test_a_copy_checks_the_settings_it_is_given
      assert_equal 'max_retries must be an Integer of at least 0, not "1"', message_of { Client.new.with(max_retries: "1") }
    end

    def test_reconnects_that_are_neither_a_count_nor_infinity_are_refused_when_the_stream_is_built
      messages = ["5", nil, 1.5, -1, -Float::INFINITY].map { |value| message_of { Client.new.streaming(max_reconnects: value) } }

      assert_equal ['"5"', "nil", "1.5", "-1", "-Infinity"].map { |value| "max_reconnects must be an Integer of at least 0, or Float::INFINITY for no limit, not #{value}" }, messages
    end

    def test_reconnects_of_zero_or_infinity_are_allowed
      assert_equal [0, Float::INFINITY], [0, Float::INFINITY].map { |value| Client.new.streaming(max_reconnects: value).max_reconnects }
    end

    def test_the_validator_returns_what_it_checked
      validator = Core::SettingValidator

      assert_equal [2, 900, Float::INFINITY], [validator.count!(:max_retries, 2), validator.seconds!(:max_rate_limit_wait, 900), validator.count_or_infinity!(:max_reconnects, Float::INFINITY)]
      refute_respond_to validator, :count?
    end
  end
end
