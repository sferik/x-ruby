# frozen_string_literal: true

require_relative "invalid_media"
require_relative "invalid_media_type"
require_relative "signature"
require_relative "source"
require_relative "utils"

module X
  module Uploader
    # Validates media upload parameters
    #
    # Internal to x-uploader: the uploaders validate their arguments with it.
    #
    # @api private
    module Validator
      extend self

      # Number of bytes per megabyte
      BYTES_PER_MB = 1_048_576
      # Greatest number of characters of alt text the API takes
      MAX_ALT_TEXT_LENGTH = 1000
      # The pattern of the language code of subtitles, two letters, which the API takes in upper case
      LANGUAGE_CODE = /\A[a-z]{2}\z/i
      # Greatest number of segments an upload in chunks can have: the OpenAPI specification of the API v2 takes a
      # segment_index of 0 to 9999, so an upload in more chunks than these would fail partway, once the media uploaded
      # so far had been billed. Chunks of MAX_CHUNK bytes upload 52 GB of media in them, more than the MAX_UPLOAD_BYTES
      # the API takes of any upload
      MAX_SEGMENTS = 10_000
      # Greatest number of bytes in a segment of an upload in chunks: the guide to chunked uploads says to keep each
      # segment at or below 5 MB, of the 8 MB the server takes at most, so a chunk is 5 megabytes at most, which is
      # below 8 MB whether a megabyte is read as 1,000,000 bytes or as 1,048,576
      MAX_CHUNK = 5 * BYTES_PER_MB
      # Greatest number of chunks uploaded at once: each holds a chunk of up to MAX_CHUNK bytes in memory and a
      # connection of its own, so 16 hold 80 megabytes on twice the 8 connections a client keeps open to a host,
      # and more would hold more of both than an upload gains from, since the connections the client does not keep
      # are opened again for each chunk
      MAX_CONCURRENCY = 16
      # Greatest number of bytes the API takes in a single upload request, above which an animated GIF, which it
      # takes in chunks of up to 15 MB, uploads in chunks
      MAX_SIMPLE_UPLOAD_BYTES = 5 * BYTES_PER_MB
      # The media types of the images a profile image or banner takes
      PROFILE_IMAGE_TYPES = %w[image/gif image/jpeg image/png].freeze
      # Valid media category values
      MEDIA_CATEGORIES = %w[amplify_video dm_gif dm_image dm_video subtitles tweet_gif tweet_image tweet_video].map(&:freeze).freeze
      # Greatest number of bytes the API takes of media of each category that documents a size of its own for every
      # account: the guides to media on docs.x.com give 5 MB for an image and 15 MB for a GIF, whether or not the
      # user has X Premium, and 1 MB for subtitles, and the API has refused an image of more than 5,242,880 bytes,
      # so a megabyte is 1,048,576 bytes. The size of a video depends on the account, so none is checked but the
      # MAX_UPLOAD_BYTES of any upload.
      MAX_MEDIA_BYTES = {
        "dm_image" => 5 * BYTES_PER_MB, "tweet_image" => 5 * BYTES_PER_MB, "dm_gif" => 15 * BYTES_PER_MB,
        "tweet_gif" => 15 * BYTES_PER_MB, "subtitles" => BYTES_PER_MB
      }.freeze
      # Greatest number of bytes the API takes of any upload: the OpenAPI specification of the API v2 takes a
      # total_bytes of at most 17,179,869,184, 16 gigabytes of 1,073,741,824 bytes, to initialize an upload with
      MAX_UPLOAD_BYTES = 16 * 1024 * BYTES_PER_MB

      # Validate the arguments of an upload, and give its media category in lowercase
      #
      # It validates everything an upload can be refused for before it sends a request, so that no media is uploaded,
      # and billed, for an upload that cannot finish. A media category of nil is inferred with the block, once the
      # media is known to exist and hold something, so that media that holds nothing raises for that, rather than for
      # a category nothing names.
      #
      # @api private
      # @param source [Source] the media to upload
      # @param media_category [String, Symbol, nil] the media category, in any case, or nil to infer it
      # @param alt_text [String, nil] the alt text of the media, or nil for media described with none
      # @param chunk_size_mb [Float, Integer, nil] the size of each chunk in megabytes, or nil to derive one
      # @param concurrency [Integer] the number of chunks uploaded at once, of 1 to MAX_CONCURRENCY
      # @param processing_timeout [Integer, Float] the seconds to wait for the media to process
      # @yieldreturn [String, Symbol] the media category inferred from the media, when none is given
      # @return [String] the media category in lowercase
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [InvalidMedia] if the media cannot be read, is empty, or is larger than the API takes of its category
      # @raise [ArgumentError] if the media category is invalid, the alt text is empty or too long, the chunk size is
      #   not a positive, finite number or is larger than a segment the API takes, the concurrency is not 1 to
      #   MAX_CONCURRENCY, or the processing timeout is not a number of seconds
      # @example Validate the arguments of an upload
      #   Uploader::Validator.validate_upload!(source, :TWEET_IMAGE, alt_text: nil, chunk_size_mb: nil, concurrency: 4,
      #     processing_timeout: 300) # => "tweet_image"
      def validate_upload!(source, media_category, alt_text:, chunk_size_mb:, concurrency:, processing_timeout:)
        validate_source!(source)
        validate_alt_text!(alt_text)
        validate_chunks!(chunk_size_mb:, concurrency:)
        validate_processing_timeout!(processing_timeout)
        validate_media_category!(media_category || yield).tap { |category| validate_size!(source, category) }
      end

      # Validate that media is no larger than the API takes of its category
      #
      # An image, a GIF, or subtitles larger than the MAX_MEDIA_BYTES of its category would be refused once it had
      # been uploaded, and billed, so it raises before a request. A video, whose size depends on the account, is left
      # to the API, unless it is larger than the MAX_UPLOAD_BYTES the API takes of any upload, which it would refuse
      # to initialize.
      #
      # @api private
      # @param source [Source] the media to upload
      # @param media_category [String] the media category, in lowercase
      # @return [void]
      # @raise [InvalidMedia] if the media is larger than the API takes of its category
      # @example Validate the size of an image
      #   Uploader::Validator.validate_size!(source, "tweet_image")
      def validate_size!(source, media_category)
        limit = MAX_MEDIA_BYTES.fetch(media_category, MAX_UPLOAD_BYTES)
        return if source.size <= limit

        raise InvalidMedia, "#{source.description} is #{source.size} bytes, more than the #{limit} bytes the API takes of #{media_category} media"
      end

      # Validate media to upload in a single request
      #
      # Media that holds nothing, or more than the API takes of its category or in a single request, would be refused,
      # so it raises before the request. A GIF of more than a single request takes, which the API takes in chunks,
      # raises too, naming the methods that upload it in chunks.
      #
      # @api private
      # @param source [Source] the media to upload
      # @param media_category [String] the media category, in lowercase
      # @return [void]
      # @raise [InvalidMedia] if the media is empty, or larger than the API takes of its category or in a single request
      # @example Validate an image to upload in a single request
      #   Uploader::Validator.validate_single_request!(source, "tweet_image")
      def validate_single_request!(source, media_category)
        validate_source!(source)
        validate_size!(source, media_category)
        return if source.size <= MAX_SIMPLE_UPLOAD_BYTES

        raise InvalidMedia, "#{source.description} is #{source.size} bytes, more than the #{MAX_SIMPLE_UPLOAD_BYTES} bytes the API takes in a single request: pass it to upload or chunked_upload"
      end

      # Validate that the media exists, and that it holds something to upload
      #
      # Empty media would initialize an upload in chunks and finalize it without a chunk, or send a single request
      # without media, for the API to refuse either.
      #
      # @api private
      # @param source [Source] the media to validate
      # @return [void]
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [InvalidMedia] if the media cannot be read, or is empty
      # @example Validate the media of an upload
      #   Uploader::Validator.validate_source!(source)
      def validate_source!(source)
        raise Errno::ENOENT, source.description unless source.exist?
        raise InvalidMedia, "#{source.description} cannot be read: it is not a file, or not one open for reading" unless source.readable?
        raise InvalidMedia, "#{source.description} is empty: there is nothing to upload" if source.size.zero?
      end

      # Validate an image to upload as a profile image or banner
      #
      # Media that names a file must have one of the extensions given, as a path must. Media that names none, such as
      # a StringIO, must begin with the signature of a GIF, a JPEG, or a PNG image, which are the types those take.
      #
      # @api private
      # @param source [Source] the image to upload
      # @param extensions [Array<String>] the supported extensions, in lowercase and without a dot
      # @return [void]
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [InvalidMedia] if the image cannot be read, or is empty
      # @raise [InvalidMediaType] if the image is not a GIF, a JPEG, or a PNG
      # @example Validate a profile image held in memory
      #   Uploader::Validator.validate_profile_image!(source, %w[gif jpg jpeg png])
      def validate_profile_image!(source, extensions)
        validate_source!(source)
        name = source.name
        return validate_extension!(name, extensions) if name
        return if PROFILE_IMAGE_TYPES.include?(Signature.media_type(source.sniff))

        raise InvalidMediaType, "#{source.description} is not a GIF, JPEG, or PNG image, which a profile image or banner must be"
      end

      # Validate that a file has one of the extensions an upload supports
      #
      # @api private
      # @param file_path [String, Pathname] the file path to validate
      # @param extensions [Array<String>] the supported extensions, in lowercase and without a dot
      # @return [void]
      # @raise [InvalidMediaType] if the extension of the file is not supported
      # @example Validate the extension of a profile image
      #   Uploader::Validator.validate_extension!("avatar.png", %w[gif jpg jpeg png])
      def validate_extension!(file_path, extensions)
        extension = Utils.extension(file_path)
        return if extensions.include?(extension)

        raise InvalidMediaType, "Unsupported file type: #{extension}. Supported types: #{extensions.join(", ")}"
      end

      # Validate the alt text of an upload, of up to MAX_ALT_TEXT_LENGTH characters
      #
      # @api private
      # @param alt_text [String, nil] the alt text to validate, or nil for media described with none
      # @return [void]
      # @raise [ArgumentError] if the alt text is not a String, or is empty or longer than the API takes
      # @example Validate alt text
      #   Uploader::Validator.validate_alt_text!("A cat asleep on a keyboard")
      def validate_alt_text!(alt_text)
        return if alt_text.nil?
        raise ArgumentError, "alt_text must be a String, or nil for none, not #{alt_text.inspect}" unless alt_text.is_a?(String)
        return if (1..MAX_ALT_TEXT_LENGTH).cover?(alt_text.length)

        raise ArgumentError, "alt_text must be 1 to #{MAX_ALT_TEXT_LENGTH} characters, not #{alt_text.length}"
      end

      # Validate the language code of subtitles, and upcase it, as the API takes it
      #
      # The code is two letters, in any case.
      #
      # @api private
      # @param language_code [String] the language code, such as EN or en
      # @return [String] the language code in upper case
      # @raise [ArgumentError] if the language code is not two letters
      # @example Validate a language code
      #   Uploader::Validator.validate_language_code!("en") # => "EN"
      def validate_language_code!(language_code)
        return language_code.upcase if language_code.is_a?(String) && language_code.match?(LANGUAGE_CODE)

        raise ArgumentError, "language_code must be two letters, such as EN, not #{language_code.inspect}"
      end

      # Validate the chunk size and concurrency of a chunked upload
      #
      # A chunk size above the MAX_CHUNK bytes of a segment raises too, since the server would refuse the first
      # segment, once the upload had been initialized. Anything that is not a number, such as a String read from an environment variable, raises ArgumentError too,
      # rather than NoMethodError from the check, as does Float::INFINITY, which no chunk is the size of, rather than
      # FloatDomainError once the chunk size is rounded to a whole byte. A concurrency above MAX_CONCURRENCY raises
      # as well, rather than hold a chunk and a connection for each of as many threads as it names.
      #
      # @api private
      # @param chunk_size_mb [Float, Integer, nil] the size of each chunk in megabytes, which must be positive and
      #   finite, and at most 5, or nil for a chunk size derived from the file
      # @param concurrency [Integer] the number of chunks uploaded at once, of 1 to MAX_CONCURRENCY
      # @return [void]
      # @raise [ArgumentError] if the chunk size is not a positive, finite number, or is larger than a segment the API
      #   takes, or the concurrency is not an Integer of 1 to MAX_CONCURRENCY
      # @example Validate the options of a chunked upload
      #   Uploader::Validator.validate_chunks!(chunk_size_mb: 4, concurrency: 2)
      def validate_chunks!(chunk_size_mb:, concurrency:)
        raise ArgumentError, "chunk_size_mb must be a positive, finite number, not #{chunk_size_mb.inspect}" unless chunk_size_mb.nil? || positive_number?(chunk_size_mb)
        raise ArgumentError, "chunk_size_mb must be at most #{MAX_CHUNK / BYTES_PER_MB}, the megabytes of a segment the API takes, not #{chunk_size_mb}" if chunk_size_mb && chunk_size_mb * BYTES_PER_MB > MAX_CHUNK
        raise ArgumentError, "concurrency must be an Integer of 1 to #{MAX_CONCURRENCY}, not #{concurrency.inspect}" unless concurrency.instance_of?(Integer) && (1..MAX_CONCURRENCY).cover?(concurrency)
      end

      # Check whether a value is a finite real number above zero
      #
      # Float::INFINITY is not finite, and Float::NAN is neither finite nor above zero.
      #
      # @api private
      # @param value [Object] the value
      # @return [Boolean] true if the value is a positive, finite real number
      def positive_number?(value) = value.is_a?(Numeric) && value.real? && value.positive? && value.finite?

      # Validate the seconds to wait for media to process
      #
      # A processing timeout is a number of seconds, of at least 0, which Float::INFINITY is, for an upload that waits
      # for as long as processing takes. Nil is not one, so that no upload waits forever by accident.
      #
      # @api private
      # @param processing_timeout [Integer, Float] the seconds to wait
      # @return [void]
      # @raise [ArgumentError] if the processing timeout is not a number of seconds of at least 0
      # @example Validate a processing timeout
      #   Uploader::Validator.validate_processing_timeout!(1800)
      def validate_processing_timeout!(processing_timeout)
        return if processing_timeout.is_a?(Numeric) && processing_timeout.real? && processing_timeout >= 0

        raise ArgumentError, "processing_timeout must be a number of seconds of at least 0, or Float::INFINITY to wait " \
          "for as long as processing takes, not #{processing_timeout.inspect}"
      end

      # The size in bytes of the chunks a file uploads in
      #
      # The API numbers no more than MAX_SEGMENTS segments, of no more than MAX_CHUNK bytes each, which an upload in
      # more chunks, or in larger ones, would fail partway of.
      #
      # A chunk size of nil is derived from the size of the media: a megabyte, as every upload in chunks used, or the
      # size that uploads the media in MAX_SEGMENTS chunks, whichever is larger, which media no larger than the
      # MAX_UPLOAD_BYTES validate_size! takes uploads in chunks of less than MAX_CHUNK bytes.
      #
      # @api private
      # @param source [Source] the media to upload
      # @param chunk_size_mb [Float, Integer, nil] the size of each chunk in megabytes, or nil to derive one
      # @return [Integer] the size of each chunk in bytes, rounded up to a whole byte
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if chunks of the size given would be more than the API numbers
      # @example Derive the chunk size of a video
      #   Uploader::Validator.validate_segments!(source, nil) # => 1048576
      def validate_segments!(source, chunk_size_mb)
        file_size = source.size
        chunk_size = chunk_size_mb.nil? ? derived_chunk_size(file_size) : (chunk_size_mb * BYTES_PER_MB).ceil
        return chunk_size if file_size <= chunk_size * MAX_SEGMENTS

        raise ArgumentError, "chunk_size_mb of #{chunk_size_mb} uploads #{file_size} bytes in more than the #{MAX_SEGMENTS} segments the API numbers"
      end

      # The size in bytes of the chunks media is uploaded in when it is given none
      #
      # It is a megabyte, or the size that uploads the media in MAX_SEGMENTS chunks, whichever is larger.
      #
      # @api private
      # @param file_size [Integer] the size of the media in bytes
      # @return [Integer] the size of each chunk in bytes
      # @example The chunk size of a video of sixteen gigabytes
      #   Uploader::Validator.derived_chunk_size(16 * 1024**3) # => 1717987
      def derived_chunk_size(file_size) = [(file_size.to_f / MAX_SEGMENTS).ceil, BYTES_PER_MB].max

      # Validate a media category, and give it in the lowercase the API takes
      #
      # @api private
      # @param media_category [String, Symbol] the media category to validate, in any case
      # @return [String] the media category in lowercase
      # @raise [ArgumentError] if the media category is invalid
      # @example Validate a media category
      #   Uploader::Validator.validate_media_category!(:TWEET_IMAGE) # => "tweet_image"
      def validate_media_category!(media_category)
        category = media_category.to_s.downcase
        return category if MEDIA_CATEGORIES.include?(category)

        raise ArgumentError, "Invalid media_category: #{media_category}. Valid values: #{MEDIA_CATEGORIES.join(", ")}"
      end
    end
    private_constant :Validator
  end
end
