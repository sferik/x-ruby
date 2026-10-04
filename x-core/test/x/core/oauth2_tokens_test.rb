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
      assert_equal({access_token: "ACCESS", refresh_token: "REFRESH", expires_at: @expires_at, scopes: nil}, @tokens.to_h)
    end

    def test_scopes_default_to_nil
      assert_nil @tokens.scopes
    end

    def test_scopes_are_held_frozen_apart_from_those_given
      given = [+"tweet.read", +"users.read"]
      tokens = OAuth2Tokens.new(access_token: "ACCESS", scopes: given)
      given.first << "x"
      given << "offline.access"

      assert_equal %w[tweet.read users.read], tokens.scopes
      assert_equal [true, true], [tokens.scopes.frozen?, tokens.scopes.first.frozen?]
      assert_equal({access_token: "ACCESS", refresh_token: nil, expires_at: nil, scopes: %w[tweet.read users.read]}, tokens.to_h)
    end

    def test_tokens_with_other_scopes_are_not_equal
      refute_equal @tokens, OAuth2Tokens.new(**@tokens.to_h, scopes: %w[tweet.read])
    end

    def test_scopes_that_are_not_an_array_of_scopes_are_refused
      ["tweet.read", ["tweet.read", nil], ["tweet read"], [""], [:"tweet.read"], ['tweet"read'], ["tweet\\read"]].each do |scopes|
        error = assert_raises(ArgumentError, scopes.inspect) { OAuth2Tokens.new(access_token: "ACCESS", scopes:) }

        assert_equal "scopes must be an Array of Strings that each name a scope, such as %w[tweet.read users.read], " \
          "or nil if they are not known", error.message
      end
    end

    def test_scopes_of_a_subclass_of_array_are_held_as_an_array
      assert_equal [Array, %w[tweet.read]], OAuth2Tokens.new(access_token: "ACCESS", scopes: Class.new(Array).new(%w[tweet.read])).scopes.then { [it.class, it] }
    end

    def test_no_scopes_are_held_as_none
      assert_equal [], OAuth2Tokens.new(access_token: "ACCESS", scopes: []).scopes
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

    def test_tokens_that_are_not_strings_are_refused_by_name_and_class
      error = assert_raises(ArgumentError) { OAuth2Tokens.new(access_token: 1, refresh_token: "REFRESH") }

      assert_equal "access_token must be a String, not a Integer", error.message
      assert_equal "access_token must be a String, not a NilClass",
        assert_raises(ArgumentError) { OAuth2Tokens.new(access_token: nil, refresh_token: "REFRESH") }.message
    end

    def test_a_refresh_token_that_is_neither_a_string_nor_nil_is_refused
      assert_equal "refresh_token must be a String or nil, not a Integer",
        assert_raises(ArgumentError) { OAuth2Tokens.new(access_token: "ACCESS", refresh_token: 1) }.message
    end

    def test_tokens_issued_without_a_refresh_token
      tokens = OAuth2Tokens.new(access_token: "ACCESS", expires_at: @expires_at)

      assert_nil tokens.refresh_token
      assert_equal({access_token: "ACCESS", refresh_token: nil, expires_at: @expires_at, scopes: nil}, tokens.to_h)
      assert_equal tokens, OAuth2Tokens.new(access_token: "ACCESS", refresh_token: nil, expires_at: @expires_at)
    end

    def test_tokens_of_a_subclass_of_string_are_accepted
      token = Class.new(String).new("ACCESS")

      assert_equal "ACCESS", OAuth2Tokens.new(access_token: token, refresh_token: "REFRESH").access_token
      assert_equal "ACCESS", OAuth2Tokens.new(access_token: "ACCESS", refresh_token: token).refresh_token
    end

    def test_empty_tokens_are_refused
      assert_match(/\Aaccess_token is nil or empty/, assert_raises(ArgumentError) { OAuth2Tokens.new(access_token: " ", refresh_token: "REFRESH") }.message)
      assert_match(/\Arefresh_token is empty/, assert_raises(ArgumentError) { OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "") }.message)
    end

    def test_an_expiration_time_that_is_not_a_time_is_refused
      [1_900_000_000, "2030-03-17T17:46:40Z"].each do |expires_at|
        error = assert_raises(ArgumentError) { OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "REFRESH", expires_at:) }

        assert_match(/\Aexpires_at must be a Time/, error.message)
      end
    end
  end
end
