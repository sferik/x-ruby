require_relative "../../test_helper"

module X
  class UploaderMediaProcessingFailedTest < Minitest::Test
    cover Uploader::MediaProcessingFailed

    def test_the_message_is_the_reason_x_gives
      status = {"processing_info" => {"state" => "failed", "error" => {"code" => 1, "name" => "InvalidMedia", "message" => "Unsupported video format"}}}
      error = Uploader::MediaProcessingFailed.new(status)

      assert_equal ["Unsupported video format", status], [error.message, error.status]
      assert_kind_of Error, error
    end

    def test_the_message_without_a_reason
      assert_equal ["Media processing failed"] * 2,
        [Uploader::MediaProcessingFailed.new({"processing_info" => {"state" => "failed"}}), Uploader::MediaProcessingFailed.new({})].map(&:message)
    end
  end

  class UploaderMediaProcessingTimeoutTest < Minitest::Test
    cover Uploader::MediaProcessingTimeout

    def test_holds_the_last_status_and_names_the_timeout
      status = {"processing_info" => {"state" => "in_progress"}}
      error = Uploader::MediaProcessingTimeout.new(status, 600)

      assert_equal [status, "Media processing did not finish within 600 seconds"], [error.status, error.message]
      assert_kind_of Error, error
    end
  end

  class UploaderInvalidMediaTypeTest < Minitest::Test
    def test_the_old_name_is_gone
      refute X.const_defined?(:InvalidMediaType)
    end
  end

  class UploaderErrorTest < Minitest::Test
    cover Uploader::Error

    def test_every_error_of_an_upload_is_an_uploader_error
      errors = [Uploader::InvalidMediaType.new, Uploader::MediaProcessingFailed.new({}), Uploader::MediaProcessingTimeout.new({}, 600)]

      assert(errors.all? { |error| error.is_a?(Uploader::Error) })
      assert(errors.all? { |error| error.is_a?(Error) })
    end

    def test_an_uploader_error_is_an_error_of_the_api
      assert_equal [Error, StandardError], Uploader::Error.ancestors.grep(Class).drop(1).take(2)
    end
  end
end
