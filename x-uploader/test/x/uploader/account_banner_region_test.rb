# frozen_string_literal: true

require "stringio"
require_relative "../../test_helper"
require "x/uploader/account"

module X
  # The region of a profile banner is given in whole pixels, which are checked before any request
  class AccountBannerRegionTest < Minitest::Test
    cover Uploader::Account
    cover Uploader.const_get(:Validator)

    PROFILE_BANNER_URL = "https://api.x.com/1.1/account/update_profile_banner.json"
    PNG = File.binread("test/sample_files/sample.png").freeze

    def setup
      @client = Client.new(**test_oauth_credentials)
      stub_request(:post, PROFILE_BANNER_URL)
    end

    def test_a_region_of_whole_pixels_is_sent
      update(width: 1, height: 1, offset_left: 0, offset_top: 0)

      assert_requested(:post, PROFILE_BANNER_URL) do |request|
        %w[width height offset_left offset_top].all? { |field| request.body.include?("name=\"#{field}\"") }
      end
    end

    def test_a_region_of_no_dimensions_is_sent_without_them
      update(width: nil, height: nil, offset_left: nil, offset_top: nil)

      assert_requested(:post, PROFILE_BANNER_URL) { |request| !request.body.include?("name=\"width\"") }
    end

    def test_a_width_or_height_that_is_not_a_positive_integer_is_refused_before_any_request
      [[:width, 0], [:height, -1], [:width, "abc"], [:height, 500.0], [:width, "1500"]].each do |name, pixels|
        error = assert_raises(ArgumentError) { update(name => pixels) }

        assert_equal "#{name} must be an Integer of pixels of at least 1, or nil, not #{pixels.inspect}", error.message
      end
      assert_not_requested :post, PROFILE_BANNER_URL
    end

    def test_an_offset_that_is_not_an_integer_of_at_least_zero_is_refused_before_any_request
      [[:offset_left, -1], [:offset_top, "0"], [:offset_left, 0.0]].each do |name, pixels|
        error = assert_raises(ArgumentError) { update(name => pixels) }

        assert_equal "#{name} must be an Integer of pixels of at least 0, or nil, not #{pixels.inspect}", error.message
      end
      assert_not_requested :post, PROFILE_BANNER_URL
    end

    def test_the_region_is_refused_before_the_media_is_read
      error = assert_raises(ArgumentError) { Uploader::Account.update_profile_banner("nope.png", client: @client, width: "abc") }

      assert_match(/\Awidth must be/, error.message)
    end

    def test_the_client_method_checks_the_region
      @client.extend(Uploader::API)

      assert_raises(ArgumentError) { @client.update_profile_banner(StringIO.new(PNG), width: "abc") }
      assert_not_requested :post, PROFILE_BANNER_URL
    end

    private

    def update(**) = Uploader::Account.update_profile_banner(StringIO.new(PNG), client: @client, **)
  end
end
