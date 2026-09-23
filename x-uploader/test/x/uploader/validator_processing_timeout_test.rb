# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  # A processing timeout is validated before the first request, so that no media is uploaded, and billed, for an
  # upload that could not wait for it
  class ValidatorProcessingTimeoutTest < Minitest::Test
    cover Uploader.const_get(:Validator)
    cover Uploader::MediaUpload

    MESSAGE = "processing_timeout must be a number of seconds of at least 0, or Float::INFINITY to wait for as long " \
      "as processing takes, not %s"

    def validator = Uploader.const_get(:Validator)

    def test_a_number_of_seconds_of_at_least_zero_is_a_processing_timeout
      [0, 1, 1.5, Rational(1, 2), Float::INFINITY].each do |processing_timeout|
        assert_nil validator.validate_processing_timeout!(processing_timeout), processing_timeout.inspect
      end
    end

    def test_anything_else_is_not
      [nil, "60", -1, -0.5, Float::NAN, Complex(1, 1), -Float::INFINITY].each do |processing_timeout|
        error = assert_raises(ArgumentError, processing_timeout.inspect) { validator.validate_processing_timeout!(processing_timeout) }

        assert_equal format(MESSAGE, processing_timeout.inspect), error.message
      end
    end

    def test_an_upload_with_no_processing_timeout_sends_no_request
      assert_raises(ArgumentError) { Uploader::MediaUpload.upload("test/sample_files/sample.mp4", client: Client.new, processing_timeout: nil) }
      assert_not_requested :any, /api\.x\.com/
    end

    def test_awaiting_processing_with_no_processing_timeout_sends_no_request
      assert_raises(ArgumentError) { Uploader::MediaUpload.await_processing("1", client: Client.new, processing_timeout: nil) }
      assert_raises(ArgumentError) { Uploader::MediaUpload.await_processing!("1", client: Client.new, processing_timeout: "60") }
      assert_not_requested :any, /api\.x\.com/
    end
  end
end
