# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class UploaderMediaProcessingFailedTest < Minitest::Test
    cover MediaProcessingFailed

    def test_the_message_is_the_reason_x_gives
      status = {"processing_info" => {"state" => "failed", "error" => {"code" => 1, "name" => "InvalidMedia", "message" => "Unsupported video format"}}}
      error = MediaProcessingFailed.new(status:)

      assert_equal ["Unsupported video format", status], [error.message, error.status]
      assert_kind_of Error, error
    end

    def test_the_message_without_a_reason
      assert_equal ["Media processing failed"] * 3,
        [MediaProcessingFailed.new(status: {"processing_info" => {"state" => "failed"}}), MediaProcessingFailed.new(status: {}), MediaProcessingFailed.new].map(&:message)
    end

    def test_the_default_message_is_private
      assert_raises(NameError) { MediaProcessingFailed::DEFAULT_MESSAGE }
    end

    def test_a_message_given_is_the_message_whatever_the_status
      status = {"processing_info" => {"error" => {"message" => "Unsupported video format"}}}

      assert_equal ["Stubbed", status], MediaProcessingFailed.new("Stubbed", status:).then { |error| [error.message, error.status] }
    end

    def test_it_is_raised_with_a_message_alone
      error = assert_raises(MediaProcessingFailed) { raise MediaProcessingFailed, "Stubbed" }

      assert_equal ["Stubbed", nil], [error.message, error.status]
    end
  end

  class UploaderMediaProcessingTimeoutTest < Minitest::Test
    cover MediaProcessingTimeout

    def test_holds_the_last_status_and_names_the_timeout
      status = {"processing_info" => {"state" => "in_progress"}}
      error = MediaProcessingTimeout.new(status:, timeout: 600)

      assert_equal [status, 600, "Media processing did not finish within 600 seconds"], [error.status, error.timeout, error.message]
      assert_kind_of Error, error
    end

    def test_a_message_given_is_the_message_whatever_the_timeout
      assert_equal "Stubbed", MediaProcessingTimeout.new("Stubbed", timeout: 600).message
    end

    def test_it_is_raised_with_a_message_alone
      error = assert_raises(MediaProcessingTimeout) { raise MediaProcessingTimeout, "Stubbed" }

      assert_equal ["Stubbed", nil, nil], [error.message, error.status, error.timeout]
    end

    def test_the_message_without_a_timeout
      assert_equal "Media processing did not finish", MediaProcessingTimeout.new.message
    end
  end

  class UploaderMissingDataTest < Minitest::Test
    cover MissingData

    def test_it_is_the_failure_of_an_upload_and_of_the_api
      error = MissingData.new("The response of the upload holds no media")

      assert_kind_of Uploader::Error, error
      assert_kind_of Error, error
    end
  end

  class UploaderErrorNamesTest < Minitest::Test
    # Every class a caller names is under X, as the classes of x-core are, and X::Uploader::Error alone is left
    # under the gem's module, for the rescue that means the failure of an upload alone.
    PROMOTED = %i[AltTextFailed InvalidMediaType MediaProcessingFailed MediaProcessingTimeout MissingData UploadedMedia].freeze

    def test_each_is_named_under_x
      PROMOTED.each { |name| assert X.const_defined?(name, false), "X::#{name} is not defined" }
    end

    def test_none_is_named_under_uploader
      PROMOTED.each { |name| refute Uploader.const_defined?(name, false), "X::Uploader::#{name} is defined" }
    end

    def test_the_base_of_an_upload_failure_stays_under_uploader
      assert Uploader.const_defined?(:Error, false)
    end
  end

  class UploaderAltTextFailedTest < Minitest::Test
    cover AltTextFailed

    def test_holds_the_media_and_names_it_with_the_reason_it_failed
      media = UploadedMedia.new({"id" => "7"})
      failure = Class.new(Error) { def message = "Connection reset" }
      error = assert_raises(AltTextFailed) { AltTextFailed.keeping(media) { raise failure } }

      assert_same media, error.media
      assert_equal ["Media 7 was uploaded, but its alt text could not be added: Connection reset"] * 2, [error.message, error.to_s]
    end

    def test_names_the_media_alone_without_a_cause
      assert_equal "Media 7 was uploaded, but its alt text could not be added", AltTextFailed.new(UploadedMedia.new({"id" => "7"})).message
    end

    def test_keeping_returns_what_the_block_returns_and_raises_what_is_not_an_error_of_the_api
      assert_equal 1, AltTextFailed.keeping(nil) { 1 }
      assert_raises(ArgumentError) { AltTextFailed.keeping(nil) { raise ArgumentError } }
    end
  end

  class UploaderErrorTest < Minitest::Test
    cover Uploader::Error

    def test_every_error_of_an_upload_is_an_uploader_error
      errors = [AltTextFailed.new(UploadedMedia.new({"id" => "7"})), InvalidMediaType.new, MediaProcessingFailed.new, MediaProcessingTimeout.new]

      assert(errors.all? { |error| error.is_a?(Uploader::Error) })
      assert(errors.all? { |error| error.is_a?(Error) })
    end

    def test_an_uploader_error_is_an_error_of_the_api
      assert_equal [Error, StandardError], Uploader::Error.ancestors.grep(Class).drop(1).take(2)
    end
  end
end
