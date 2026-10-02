# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

module X
  # JSON writes the tokens of a refresh led by the number of their format, with the expiration time as an ISO 8601
  # String, and from_json reads them back as the tokens they were
  class OAuth2TokensJSONTest < Minitest::Test
    cover OAuth2Tokens

    def setup
      @expires_at = Time.at(1_790_000_000, 123_456_789, :nsec, in: "-07:00")
      @tokens = OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "REFRESH", expires_at: @expires_at, scopes: %w[tweet.read offline.access])
    end

    def test_as_json_is_led_by_the_format_with_the_expiration_time_in_utc_to_the_nanosecond
      assert_equal({"format" => 1, "access_token" => "ACCESS", "refresh_token" => "REFRESH",
                    "expires_at" => "2026-09-21T14:13:20.123456789Z", "scopes" => %w[tweet.read offline.access]}, @tokens.as_json)
    end

    def test_as_json_leaves_the_expiration_time_it_reads_in_its_own_zone
      @tokens.as_json

      assert_equal(-25_200, @expires_at.utc_offset)
    end

    def test_as_json_writes_nil_for_what_the_tokens_lack
      assert_equal({"format" => 1, "access_token" => "A", "refresh_token" => nil, "expires_at" => nil, "scopes" => nil},
        OAuth2Tokens.new(access_token: "A").as_json)
    end

    def test_to_json_writes_as_json
      assert_equal JSON.generate(@tokens.as_json), @tokens.to_json
      assert_equal %({"tokens":#{@tokens.to_json}}), JSON.generate({tokens: @tokens})
    end

    def test_to_json_passes_the_state_it_is_given
      assert_equal JSON.pretty_generate(@tokens.as_json), JSON.pretty_generate(@tokens)
    end

    def test_tokens_written_as_json_read_back_as_they_were
      loaded = OAuth2Tokens.from_json(@tokens.to_json)

      assert_equal [@tokens, true, @expires_at], [loaded, loaded.frozen?, loaded.expires_at]
      assert_equal OAuth2Tokens.new(access_token: "A"), OAuth2Tokens.from_json(OAuth2Tokens.new(access_token: "A").to_json)
    end

    def test_tokens_read_back_from_json_in_a_subclass_of_string
      assert_equal @tokens, OAuth2Tokens.from_json(Class.new(String).new(@tokens.to_json))
    end

    def test_tokens_read_back_from_the_hash_of_as_json
      assert_equal @tokens, OAuth2Tokens.from_json(@tokens.as_json)
      assert_equal @tokens, OAuth2Tokens.from_json(Class.new(Hash).new.merge!(@tokens.as_json))
      assert_equal @tokens, OAuth2Tokens.from_json(@tokens.as_json.merge("expires_at" => Class.new(String).new(@tokens.as_json["expires_at"])))
    end

    def test_tokens_read_back_from_a_hash_keyed_by_symbol
      assert_equal @tokens, OAuth2Tokens.from_json(@tokens.as_json.transform_keys(&:to_sym))
      assert_equal @tokens, OAuth2Tokens.from_json(JSON.parse(@tokens.to_json, symbolize_names: true))
    end

    def test_tokens_a_later_release_added_to_read_back_as_they_were
      assert_equal @tokens, OAuth2Tokens.from_json(@tokens.as_json.merge("token_type" => "bearer"))
    end

    def test_json_of_another_format_is_refused
      error = assert_raises(UnsupportedMarshalFormat) { OAuth2Tokens.from_json(@tokens.as_json.merge("format" => "1")) }

      assert_equal 'X::OAuth2Tokens reads format 1 of JSON, not "1"', error.message
      assert_raises(UnsupportedMarshalFormat) { OAuth2Tokens.from_json(@tokens.as_json.except("format")) }
    end

    def test_json_that_is_not_an_object_is_refused
      error = assert_raises(ArgumentError) { OAuth2Tokens.from_json("[]") }

      assert_equal "the JSON of X::OAuth2Tokens must be an object, not a Array", error.message
      assert_raises(ArgumentError) { OAuth2Tokens.from_json(nil) }
    end

    def test_an_expiration_time_that_is_not_a_string_is_refused
      error = assert_raises(ArgumentError) { OAuth2Tokens.from_json(@tokens.as_json.merge("expires_at" => 1_790_000_000)) }

      assert_equal "the expires_at of the JSON of X::OAuth2Tokens must be an ISO 8601 String or nil, not a Integer", error.message
      assert_raises(ArgumentError) { OAuth2Tokens.from_json(@tokens.as_json.merge("expires_at" => "tomorrow")) }
    end

    def test_tokens_the_constructor_refuses_are_refused
      assert_raises(ArgumentError) { OAuth2Tokens.from_json(@tokens.as_json.merge("access_token" => nil)) }
      assert_raises(ArgumentError) { OAuth2Tokens.from_json({"format" => 1}) }
    end

    def test_what_the_json_leaves_out_reads_back_as_nil
      assert_equal OAuth2Tokens.new(access_token: "A"), OAuth2Tokens.from_json({"format" => 1, "access_token" => "A"})
    end

    def test_json_that_does_not_parse_raises_a_parser_error
      assert_raises(JSON::ParserError) { OAuth2Tokens.from_json("{") }
    end

    def test_the_json_constants_are_named_privately
      assert_raises(NameError) { OAuth2Tokens::NOT_AN_OBJECT }
      assert_raises(NameError) { OAuth2Tokens::NOT_A_TIME_STRING }
      assert_raises(NameError) { OAuth2Tokens::FRACTION_DIGITS }
    end
  end
end
