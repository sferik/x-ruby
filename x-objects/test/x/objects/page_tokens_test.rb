# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A page reads the tokens of the pages after and before it from its meta, an empty one as none
  class PageTokensTest < Minitest::Test
    cover Page

    def test_next_token
      assert_equal "abc", Page.new([], meta: {next_token: "abc", result_count: 2}).next_token
      assert_nil Page.new([]).next_token
    end

    def test_an_empty_next_token_names_no_page
      assert_nil Page.new([], meta: {"next_token" => ""}).next_token
      assert_equal " ", Page.new([], meta: {"next_token" => " "}).next_token
    end

    def test_previous_token
      assert_equal "xyz", Page.new([], meta: {"previous_token" => "xyz", "next_token" => "abc"}).previous_token
      assert_nil Page.new([], meta: {"next_token" => "abc"}).previous_token
      assert_nil Page.new([]).previous_token
    end

    def test_an_empty_previous_token_names_no_page
      assert_nil Page.new([], meta: {"previous_token" => ""}).previous_token
      assert_equal " ", Page.new([], meta: {"previous_token" => " "}).previous_token
    end
  end
end
