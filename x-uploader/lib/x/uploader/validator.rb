# frozen_string_literal: true

require_relative "invalid_media"
require_relative "invalid_media_type"
require_relative "signature"
require_relative "source"

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
      # The least number of pixels each dimension of the region of a profile banner takes: a width and a height hold at
      # least one, and an offset none
      BANNER_REGION = {width: 1, height: 1, offset_left: 0, offset_top: 0}.freeze
      # Greatest number of bytes the API v1.1 takes of a profile image: its reference for update_profile_image takes an
      # image of less than 700 kilobytes, each of 1,024 bytes, as a megabyte here is 1,048,576
      MAX_PROFILE_IMAGE_BYTES = 700 * 1024
      # Greatest number of bytes X takes of a profile banner: the reference of the API v1.1 for update_profile_banner
      # names none, and answers a banner too large with 422, and the help of X gives 5 MB for a header photo
      MAX_PROFILE_BANNER_BYTES = 5 * BYTES_PER_MB
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
      # @param chunk_size [Integer, nil] the size of each chunk in bytes, or nil to derive one
      # @param concurrency [Integer] the number of chunks uploaded at once, of 1 to MAX_CONCURRENCY
      # @param processing_timeout [Integer, Float] the seconds to wait for the media to process
      # @yieldreturn [String, Symbol] the media category inferred from the media, when none is given
      # @return [String] the media category in lowercase
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [InvalidMedia] if the media cannot be read, is empty, or is larger than the API takes of its category
      # @raise [ArgumentError] if the media category is invalid, the alt text is empty or too long, the chunk size is
      #   not a positive Integer or is larger than a segment the API takes, the concurrency is not 1 to
      #   MAX_CONCURRENCY, or the processing timeout is not a number of seconds
      # @example Validate the arguments of an upload
      #   Uploader::Validator.validate_upload!(source, :TWEET_IMAGE, alt_text: nil, chunk_size: nil, concurrency: 4,
      #     processing_timeout: 300) # => "tweet_image"
      def validate_upload!(source, media_category, alt_text:, chunk_size:, concurrency:, processing_timeout:)
        validate_source!(source)
        validate_alt_text!(alt_text)
        validate_chunks!(chunk_size:, concurrency:)
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
      # The image must begin with the signature of a GIF, a JPEG, or a PNG, which are the types those take, whatever
      # the name of its file, so that a PNG in a Tempfile is taken, and a video named .png is not read whole and sent.
      # An image larger than the endpoint takes would be refused once it had been sent, so it raises before.
      #
      # @api private
      # @param source [Source] the image to upload
      # @param max_bytes [Integer] the greatest number of bytes the endpoint takes
      # @param use [String] what the image is uploaded as, for the message of an error
      # @return [void]
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [InvalidMedia] if the image cannot be read, is empty, or is larger than max_bytes
      # @raise [InvalidMediaType] if the image does not begin with the signature of a GIF, a JPEG, or a PNG
      # @example Validate a profile image
      #   Uploader::Validator.validate_profile_image!(source, 716_800, "a profile image")
      def validate_profile_image!(source, max_bytes, use)
        validate_source!(source)
        raise InvalidMediaType, "#{source.description} is not a GIF, JPEG, or PNG image, which #{use} must be" unless PROFILE_IMAGE_TYPES.include?(Signature.media_type(source.sniff))
        return if source.size <= max_bytes

        raise InvalidMedia, "#{source.description} is #{source.size} bytes, more than the #{max_bytes} bytes the API takes of #{use}"
      end

      # Validate the region of a profile banner to crop it to
      #
      # The reference of the API v1.1 for update_profile_banner takes the width and height of the region of the image
      # to use, and its offsets from the left and the top, each in pixels. A width or height is a positive Integer,
      # and an offset an Integer of at least 0, or nil for none, so that anything else, such as a String read from a
      # form, raises before any request, rather than be sent as whatever its to_s reads.
      #
      # @api private
      # @param region [Hash{Symbol => Integer, nil}] the width and height of the region, and its offset_left and
      #   offset_top, in pixels
      # @return [void]
      # @raise [ArgumentError] if a width or height is not a positive Integer, or an offset not an Integer of at
      #   least 0, and is not nil
      # @example Validate the region of a banner
      #   Uploader::Validator.validate_banner_region!(width: 1500, height: 500, offset_left: 0, offset_top: nil)
      def validate_banner_region!(**region)
        region.each do |name, pixels|
          least = BANNER_REGION.fetch(name)
          next if pixels.nil? || whole_number?(pixels, least)

          raise ArgumentError, "#{name} must be an Integer of pixels of at least #{least}, or nil, not #{pixels.inspect}"
        end
      end

      # Validate the alt text of an upload, of up to MAX_ALT_TEXT_LENGTH characters
      #
      # The alt text is sent as JSON, which is UTF-8, so text of another encoding is sent as the UTF-8 it converts to,
      # and text that converts to none, such as bytes that are not UTF-8, is refused here, before the media it
      # describes is uploaded, rather than fail to be sent once it is.
      #
      # @api private
      # @param alt_text [String, nil] the alt text to validate, or nil for media described with none
      # @return [void]
      # @raise [ArgumentError] if the alt text is not a String, does not convert to UTF-8, or is empty or longer than
      #   the API takes
      # @example Validate alt text
      #   Uploader::Validator.validate_alt_text!("A cat asleep on a keyboard")
      def validate_alt_text!(alt_text)
        return if alt_text.nil?
        raise ArgumentError, "alt_text must be a String, or nil for none, not #{alt_text.inspect}" unless alt_text.is_a?(String)
        raise ArgumentError, "alt_text must be text that converts to UTF-8, not #{alt_text.inspect}" unless utf8?(alt_text)
        return if (1..MAX_ALT_TEXT_LENGTH).cover?(alt_text.length)

        raise ArgumentError, "alt_text must be 1 to #{MAX_ALT_TEXT_LENGTH} characters, not #{alt_text.length}"
      end

      # Check whether text converts to UTF-8, as the JSON it is sent in is written
      # @api private
      # @param text [String] the text
      # @return [Boolean] true if the text converts to valid UTF-8
      # @example Check text that holds a byte that is not UTF-8
      #   Uploader::Validator.utf8?("\xFF".b) # => false
      def utf8?(text)
        text.encode(Encoding::UTF_8).valid_encoding?
      rescue EncodingError
        false
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
      # A chunk size is a whole number of bytes, so anything else, such as a Float or a String read from an
      # environment variable, raises ArgumentError, rather than be rounded to one. A chunk size above the MAX_CHUNK
      # bytes of a segment raises too, since the server would refuse the first segment, once the upload had been
      # initialized. A concurrency above MAX_CONCURRENCY raises as well, rather than hold a chunk and a connection for
      # each of as many threads as it names.
      #
      # @api private
      # @param chunk_size [Integer, nil] the size of each chunk in bytes, which must be positive and at most
      #   MAX_CHUNK, or nil for a chunk size derived from the file
      # @param concurrency [Integer] the number of chunks uploaded at once, of 1 to MAX_CONCURRENCY
      # @return [void]
      # @raise [ArgumentError] if the chunk size is not a positive Integer, or is larger than a segment the API takes,
      #   or the concurrency is not an Integer of 1 to MAX_CONCURRENCY
      # @example Validate the options of a chunked upload
      #   Uploader::Validator.validate_chunks!(chunk_size: 4_194_304, concurrency: 2)
      def validate_chunks!(chunk_size:, concurrency:)
        raise ArgumentError, "chunk_size must be a positive Integer of bytes, not #{chunk_size.inspect}" unless chunk_size.nil? || whole_number?(chunk_size, 1)
        raise ArgumentError, "chunk_size must be at most #{MAX_CHUNK}, the bytes of a segment the API takes, not #{chunk_size}" if chunk_size && chunk_size > MAX_CHUNK
        raise ArgumentError, "concurrency must be an Integer of 1 to #{MAX_CONCURRENCY}, not #{concurrency.inspect}" unless concurrency.instance_of?(Integer) && (1..MAX_CONCURRENCY).cover?(concurrency)
      end

      # Check whether a value is a whole number of at least the least given
      #
      # A number of bytes or pixels is one. A Float is not, even a whole one, nor is a Rational, so that no size is
      # rounded to a byte or a pixel.
      #
      # @api private
      # @param value [Object] the value
      # @param least [Integer] the least the number may be
      # @return [Boolean] true if the value is an Integer of at least the least given
      def whole_number?(value, least) = value.instance_of?(Integer) && value >= least

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
      # @param chunk_size [Integer, nil] the size of each chunk in bytes, or nil to derive one
      # @return [Integer] the size of each chunk in bytes
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if chunks of the size given would be more than the API numbers
      # @example Derive the chunk size of a video
      #   Uploader::Validator.validate_segments!(source, nil) # => 1048576
      def validate_segments!(source, chunk_size)
        file_size = source.size
        size = chunk_size || derived_chunk_size(file_size)
        return size if file_size <= size * MAX_SEGMENTS

        raise ArgumentError, "chunk_size of #{chunk_size} bytes uploads #{file_size} bytes in more than the #{MAX_SEGMENTS} segments the API numbers"
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
