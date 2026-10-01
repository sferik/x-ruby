# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientTimeoutsValidationTest < Minitest::Test
    cover_client
    cover Core.const_get(:Connection)
    cover Core.const_get(:SettingValidator)
    cover OAuth2Authorization

    TIMEOUTS = %i[open_timeout read_timeout write_timeout].freeze

    def message_of(&) = assert_raises(ArgumentError, &).message

    def test_a_timeout_that_is_neither_finite_seconds_of_at_least_zero_nor_nil_is_refused_when_the_client_is_built
      TIMEOUTS.each do |name|
        messages = ["5", -1, Float::INFINITY, Float::NAN, Complex(1, 0)].map { |value| message_of { Client.new(name => value) } }

        assert_equal ['"5"', "-1", "Infinity", "NaN", "(1+0i)"].map { |value| "#{name} must be a finite number of seconds of at least 0, or nil for no timeout, not #{value}" }, messages
      end
    end

    def test_a_timeout_of_finite_seconds_of_at_least_zero_or_nil_is_allowed
      TIMEOUTS.each do |name|
        assert_equal [0, 1.5, Rational(1, 2), nil], [0, 1.5, Rational(1, 2), nil].map { |value| Client.new(name => value).public_send(name) }
      end
    end

    def test_a_keep_alive_timeout_that_is_not_finite_seconds_of_at_least_zero_is_refused
      messages = ["30", nil, -1, Float::INFINITY].map { |value| message_of { Client.new(keep_alive_timeout: value) } }

      assert_equal ['"30"', "nil", "-1", "Infinity"].map { |value| "keep_alive_timeout must be a finite number of seconds of at least 0, not #{value}" }, messages
    end

    def test_a_keep_alive_timeout_of_finite_seconds_of_at_least_zero_is_allowed
      assert_equal [0, 2.5], [0, 2.5].map { |value| Client.new(keep_alive_timeout: value).keep_alive_timeout }
    end

    def test_a_copy_checks_the_timeouts_it_is_given
      assert_equal 'open_timeout must be a finite number of seconds of at least 0, or nil for no timeout, not "5"', message_of { Client.new.with(open_timeout: "5") }
    end

    def test_an_authorization_checks_its_timeouts
      assert_equal "write_timeout must be a finite number of seconds of at least 0, or nil for no timeout, not -1",
        message_of { OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: "https://example.com/callback", write_timeout: -1) }
    end

    def test_the_validator_returns_the_timeouts_it_checked
      validator = Core.const_get(:SettingValidator)

      assert_equal [30, 60, nil], [validator.finite_seconds!(:keep_alive_timeout, 30), validator.timeout!(:read_timeout, 60), validator.timeout!(:read_timeout, nil)]
      refute_respond_to validator, :seconds?
      refute_respond_to validator, :finite_seconds?
    end
  end
end
