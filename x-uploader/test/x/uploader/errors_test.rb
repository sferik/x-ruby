# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class UploaderMediaProcessingFailedTest < Minitest::Test
    cover MediaProcessingFailed

    def test_the_message_is_the_reason_x_gives
      status = {"processing_info" => {"state" => "failed", "error" => {"code" => 1, "name" => "InvalidMedia", "message" => "Unsupported video format"}}}
      error = MediaProcessingFailed.new(media: status)

      assert_equal ["Unsupported video format", UploadedMedia.new(status)], [error.message, error.media]
      assert_kind_of Error, error
    end

    def test_holds_uploaded_media_given_as_it_was_given
      status = UploadedMedia.new({"id" => "7", "processing_info" => {"state" => "failed"}})

      assert_same status, MediaProcessingFailed.new(media: status).media
    end

    def test_holds_a_status_given_as_a_subclass_of_hash_as_uploaded_media
      status = Class.new(Hash).new.merge!("processing_info" => {"state" => "failed"})

      assert_instance_of UploadedMedia, MediaProcessingFailed.new(media: status).media
    end

    def test_the_message_without_a_reason
      assert_equal ["Media processing failed"] * 3,
        [MediaProcessingFailed.new(media: {"processing_info" => {"state" => "failed"}}), MediaProcessingFailed.new(media: {}), MediaProcessingFailed.new].map(&:message)
    end

    def test_the_default_message_is_private
      assert_raises(NameError) { MediaProcessingFailed::DEFAULT_MESSAGE }
    end

    def test_a_message_given_is_the_message_whatever_the_status
      status = {"processing_info" => {"error" => {"message" => "Unsupported video format"}}}

      assert_equal ["Stubbed", UploadedMedia.new(status)], MediaProcessingFailed.new("Stubbed", media: status).then { |error| [error.message, error.media] }
    end

    def test_it_is_raised_with_a_message_alone
      error = assert_raises(MediaProcessingFailed) { raise MediaProcessingFailed, "Stubbed" }

      assert_equal ["Stubbed", nil], [error.message, error.media]
    end
  end

  class UploaderMediaProcessingTimeoutTest < Minitest::Test
    cover MediaProcessingTimeout

    def test_holds_the_last_status_and_names_the_timeout
      status = {"processing_info" => {"state" => "in_progress"}}
      error = MediaProcessingTimeout.new(media: status, timeout: 600)

      assert_equal [UploadedMedia.new(status), 600, "Media processing did not finish within 600 seconds"], [error.media, error.timeout, error.message]
      assert_kind_of Error, error
    end

    def test_holds_uploaded_media_given_as_it_was_given
      status = UploadedMedia.new({"id" => "7", "processing_info" => {"state" => "in_progress"}})

      assert_same status, MediaProcessingTimeout.new(media: status).media
    end

    def test_holds_a_status_given_as_a_subclass_of_hash_as_uploaded_media
      status = Class.new(Hash).new.merge!("processing_info" => {"state" => "in_progress"})

      assert_instance_of UploadedMedia, MediaProcessingTimeout.new(media: status).media
    end

    def test_a_message_given_is_the_message_whatever_the_timeout
      assert_equal "Stubbed", MediaProcessingTimeout.new("Stubbed", timeout: 600).message
    end

    def test_it_is_raised_with_a_message_alone
      error = assert_raises(MediaProcessingTimeout) { raise MediaProcessingTimeout, "Stubbed" }

      assert_equal ["Stubbed", nil, nil], [error.message, error.media, error.timeout]
    end

    def test_the_message_without_a_timeout
      assert_equal "Media processing did not finish", MediaProcessingTimeout.new.message
    end
  end

  class UploaderMissingMediaDataTest < Minitest::Test
    cover MissingMediaData

    def test_it_is_the_failure_of_an_upload_and_of_the_api
      error = MissingMediaData.new("The response of the upload holds no media")

      assert_kind_of Uploader::Error, error
      assert_kind_of Error, error
      assert_equal [[], true], [error.problems, error.problems.frozen?]
    end

    def test_it_names_the_reason_the_first_problem_gives_and_holds_the_problems
      problems = [Problem.new({"title" => "Not Found Error", "detail" => "Could not find media"}), Problem.new({"title" => "Other"})]
      error = MissingMediaData.new("The response holds no media", problems:)

      assert_equal ["The response holds no media: Could not find media", problems, true], [error.message, error.problems, error.problems.frozen?]
      refute_predicate problems, :frozen?
    end

    def test_it_names_the_message_or_else_the_title_of_a_problem_without_a_detail
      messages = [{"message" => "Invalid media_id", "title" => "Bad"}, {"title" => "Not Found Error"}].map do |attrs|
        MissingMediaData.new("No media", problems: [Problem.new(attrs)]).message
      end

      assert_equal ["No media: Invalid media_id", "No media: Not Found Error"], messages
    end

    def test_it_names_the_reason_alone_without_a_message_and_its_class_without_either
      assert_equal "Could not find media", MissingMediaData.new(problems: [Problem.new({"detail" => "Could not find media"})]).message
      assert_equal "X::MissingMediaData", MissingMediaData.new.message
    end
  end

  class UploaderErrorNamesTest < Minitest::Test
    # Every class a caller names is under X, as the classes of x-core are, and X::Uploader::Error alone is left
    # under the gem's module, for the rescue that means the failure of an upload alone.
    PROMOTED = %i[AltTextFailed InvalidMedia InvalidMediaType MediaProcessingFailed MediaProcessingTimeout MissingMediaData UploadedMedia].freeze

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
      error = assert_raises(AltTextFailed) { AltTextFailed.__send__(:keeping, media) { raise failure } }

      assert_same media, error.media
      assert_equal ["Media 7 was uploaded, but its alt text could not be added: Connection reset"] * 2, [error.message, error.to_s]
    end

    def test_names_the_media_alone_without_a_cause
      assert_equal "Media 7 was uploaded, but its alt text could not be added", AltTextFailed.new(media: UploadedMedia.new({"id" => "7"})).message
    end

    def test_takes_a_message_of_its_own_as_a_test_stub_raises_it
      error = assert_raises(AltTextFailed) { raise AltTextFailed, "Alt text could not be added" }

      assert_equal "Alt text could not be added", error.message
      assert_nil error.media
    end

    def test_names_no_media_when_given_none
      assert_equal "Media was uploaded, but its alt text could not be added", AltTextFailed.new.message
    end

    def test_a_message_of_its_own_ends_with_the_reason_it_failed
      error = assert_raises(AltTextFailed) do
        raise Error, "Connection reset"
      rescue Error
        raise AltTextFailed.new("No alt text", media: UploadedMedia.new({"id" => "7"}))
      end

      assert_equal ["No alt text: Connection reset", 7], [error.message, error.media.id]
    end

    def test_keeping_is_private
      refute_respond_to AltTextFailed, :keeping
    end

    def test_keeping_returns_what_the_block_returns_and_raises_what_is_not_an_error_of_the_api
      assert_equal 1, AltTextFailed.__send__(:keeping, nil) { 1 }
      assert_raises(ArgumentError) { AltTextFailed.__send__(:keeping, nil) { raise ArgumentError } }
    end
  end

  class UploaderErrorTest < Minitest::Test
    cover Uploader::Error

    def test_every_error_of_an_upload_is_an_uploader_error
      errors = [AltTextFailed.new(media: UploadedMedia.new({"id" => "7"})), InvalidMedia.new, InvalidMediaType.new, MediaProcessingFailed.new, MediaProcessingTimeout.new]

      assert(errors.all? { |error| error.is_a?(Uploader::Error) })
      assert(errors.all? { |error| error.is_a?(Error) })
    end

    def test_media_of_a_type_the_api_does_not_take_is_media_the_api_would_refuse
      assert_equal [InvalidMedia, Uploader::Error], InvalidMediaType.ancestors.grep(Class).drop(1).take(2)
    end

    def test_an_uploader_error_is_an_error_of_the_api
      assert_equal [Error, StandardError], Uploader::Error.ancestors.grep(Class).drop(1).take(2)
    end
  end
end
