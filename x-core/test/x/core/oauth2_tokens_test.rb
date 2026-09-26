# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class OAuth2TokensTest < Minitest::Test
    cover OAuth2Tokens

    def setup
      @expires_at = Time.utc(2026, 9, 26)
      @tokens = OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "REFRESH", expires_at: @expires_at)
    end

    def test_reads_the_tokens_and_their_expiration
      assert_equal ["ACCESS", "REFRESH", @expires_at], [@tokens.access_token, @tokens.refresh_token, @tokens.expires_at]
    end

    def test_is_frozen
      assert_predicate @tokens, :frozen?
    end

    def test_expires_at_defaults_to_nil
      assert_nil OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "REFRESH").expires_at
    end

    def test_to_h
      assert_equal({access_token: "ACCESS", refresh_token: "REFRESH", expires_at: @expires_at}, @tokens.to_h)
    end

    def test_tokens_with_the_same_values_are_equal
      same = OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "REFRESH", expires_at: @expires_at)

      assert_equal @tokens, same
      assert @tokens.eql?(same)
      assert_equal @tokens.hash, same.hash
      assert_equal 1, {@tokens => 1}.fetch(same)
      assert_kind_of Integer, @tokens.hash
    end

    def test_tokens_with_other_values_are_not_equal
      refute_equal @tokens, OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "OTHER", expires_at: @expires_at)
      refute_equal @tokens, @tokens.to_h
    end

    def test_tokens_with_other_values_or_of_another_class_hash_differently
      refute_equal @tokens.hash, OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "OTHER", expires_at: @expires_at).hash
      refute_equal @tokens.hash, @tokens.to_h.hash
      refute_equal @tokens.hash, Class.new(OAuth2Tokens).new(**@tokens.to_h).hash
    end

    def test_inspect_reveals_no_token
      assert_equal "#<X::OAuth2Tokens expires_at=#{@expires_at.inspect}>", @tokens.inspect
      assert_equal "#<X::OAuth2Tokens expires_at=nil>", OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "REFRESH").inspect
    end
  end
end
