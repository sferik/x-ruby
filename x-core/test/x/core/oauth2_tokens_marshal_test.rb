# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # Marshal writes the tokens of a refresh as plain data, led by the number of their format, and reads them back frozen,
  # holding the tokens, which are marshalled to be stored, while inspect still reveals neither
  class OAuth2TokensMarshalTest < Minitest::Test
    cover OAuth2Tokens

    def setup
      @expires_at = Time.utc(2026, 9, 26)
      @tokens = OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "REFRESH", expires_at: @expires_at)
    end

    def test_marshal_dump_is_plain_data_led_by_its_format
      assert_equal [1, {access_token: "ACCESS", refresh_token: "REFRESH", expires_at: @expires_at}], @tokens.marshal_dump
      assert_equal [1, {access_token: "A", refresh_token: "R", expires_at: nil}], OAuth2Tokens.new(access_token: "A", refresh_token: "R").marshal_dump
    end

    def test_marshalled_tokens_read_back_as_they_were_frozen
      loaded = Marshal.load(Marshal.dump(@tokens))

      assert_equal @tokens, loaded
      assert_equal [OAuth2Tokens, true], [loaded.class, loaded.frozen?]
    end

    def test_marshalled_tokens_are_still_not_revealed_by_inspect
      loaded = Marshal.load(Marshal.dump(@tokens))

      assert_equal "#<X::OAuth2Tokens expires_at=#{@expires_at.inspect}>", loaded.inspect
      refute_match(/ACCESS|REFRESH/, loaded.inspect)
    end

    def test_tokens_a_later_release_added_to_read_back_as_they_were
      loaded = OAuth2Tokens.allocate.tap { |tokens| tokens.marshal_load([1, {**@tokens.to_h, scope: "tweet.read"}, "added"]) }

      assert_equal @tokens, loaded
    end

    def test_tokens_of_another_format_are_refused
      error = assert_raises(UnsupportedMarshalFormat) { OAuth2Tokens.allocate.marshal_load(["1", {access_token: "A", refresh_token: "R"}]) }

      assert_equal 'X::OAuth2Tokens reads format 1 of Marshal, not "1"', error.message
      assert_raises(UnsupportedMarshalFormat) { OAuth2Tokens.allocate.marshal_load({access_token: "A"}) }
    end

    def test_the_format_is_named_privately
      assert_raises(NameError) { OAuth2Tokens::MARSHAL_FORMAT }
    end
  end
end
