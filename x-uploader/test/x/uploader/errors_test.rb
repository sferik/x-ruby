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

  class UploaderInvalidMediaTypeTest < Minitest::Test
    def test_the_old_name_is_a_deprecated_alias
      deprecated = Warning[:deprecated]
      Warning[:deprecated] = true

      assert_output(nil, /constant X::InvalidMediaType is deprecated/) { assert_same Uploader::InvalidMediaType, X::InvalidMediaType }
    ensure
      Warning[:deprecated] = deprecated
    end
  end
end
