# frozen_string_literal: true

require "x/core"
require_relative "media_processing_failed"
require_relative "media_processing_timeout"
require_relative "missing_media_data"
require_relative "multipart"
require_relative "uploaded_media"

module X
  module Uploader
    # Helpers shared across the uploaders
    #
    # Internal to x-uploader: the uploaders call it rather than mix its methods into themselves, so a class that
    # includes an uploader gains none of them.
    #
    # @api private
    module Utils
      extend self

      # The media categories the subtitles endpoint takes, by the category the video was uploaded as
      SUBTITLED_MEDIA_CATEGORIES = {"tweet_video" => "TweetVideo", "amplify_video" => "AmplifyVideo"}.freeze
      # The message of the error raised for media that holds no identifier
      NO_MEDIA_ID = "The media given holds no identifier"
      # The message of the error raised for a response of an upload that holds no media
      NO_MEDIA = "The response %s holds no media"
      # The message of the error raised for a metadata response that holds no metadata
      NO_METADATA = "The response that adds the metadata holds none"
      # The message of the error raised for something that is neither media nor the identifier of media
      NOT_MEDIA = "%s is not media: pass uploaded media, the Hash of an upload response, media that has a media key, " \
        "such as X::Media, a media key, or a media identifier"
      # The message of the error raised for a media key that names no media identifier
      NOT_MEDIA_KEY = "The media key %s names no media identifier"
      # The pattern of a media key, which names the media identifier after the number of its type and an underscore
      MEDIA_KEY = /\A\d+_(\d+)\z/
      # The pattern of a media identifier the API takes: one to nineteen digits
      MEDIA_ID = /\A\d{1,19}\z/
      # The message of the error raised for a media identifier the API would refuse
      NOT_MEDIA_ID = "The media identifier %s is none the API takes, which is 1 to 19 digits"
      # Fewest seconds to wait before a check of processing, for a status that asks for no wait
      MIN_CHECK_AFTER_SECS = 1
      # The message of the error raised for media whose processing is in no state X documents
      UNKNOWN_STATE = "Media processing is in no state X documents: %s"
      private_constant :NO_MEDIA_ID, :NO_MEDIA, :NO_METADATA, :NOT_MEDIA, :NOT_MEDIA_KEY, :MEDIA_KEY, :MEDIA_ID, :NOT_MEDIA_ID,
        :MIN_CHECK_AFTER_SECS, :UNKNOWN_STATE

      # The lowercase extension of a file, without its dot
      #
      # @api private
      # @param file_path [String, Pathname] the path to the file
      # @return [String] the extension
      # @example The extension of a file
      #   Uploader::Utils.extension("cat.JPG") # => "jpg"
      def extension(file_path) = File.extname(file_path).delete(".").downcase

      # The options of an uploader a method of a client was given, which name no client
      #
      # A method of a client uploads with that client, so a client among the options, which would upload with the
      # credentials of another, raises as a keyword the method does not take raises, rather than take its place.
      #
      # @api private
      # @param options [Hash{Symbol => Object}] the options the method was given
      # @return [Hash{Symbol => Object}] the options
      # @raise [ArgumentError] if the options name a client
      # @example The options of an upload of a client
      #   Uploader::Utils.without_client(media_category: "tweet_image") # => {media_category: "tweet_image"}
      def without_client(options)
        raise ArgumentError, "unknown keyword: :client" if options.key?(:client)

        options
      end

      # The media identifier of an upload response, of media, or of an identifier
      #
      # Media that is not what an upload returned, such as the X::Media of x-objects, which this gem does not depend
      # on, is read from its media key, which names the identifier after the number of its type, as 3_7 names 7, and
      # a String that is a media key is read the same way, as the media_ids of a new post read one.
      #
      # Nil, or an empty identifier, names no media, and would reach the API as an identifier that is not there, so it
      # raises ArgumentError, as a mistake of the caller: every response an upload builds media from holds an
      # identifier, or raises MissingMediaData where it is read. Anything else raises rather than reach the API as
      # whatever its to_s reads, such as the inspection of an object.
      #
      # @api private
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, the upload response, media
      #   that has a media key, the media key, or the media identifier
      # @return [String] the media identifier
      # @raise [ArgumentError] if the media is nil or empty, neither media, a media key, nor a media identifier, holds
      #   no identifier, has no media key or one that names no identifier, or its identifier is none the API takes,
      #   which is 1 to 19 digits
      # @example The identifier of uploaded media
      #   Uploader::Utils.media_id({"id" => "1880028106020515840"}) # => "1880028106020515840"
      # @example The identifier of media of a post
      #   Uploader::Utils.media_id(X::Media.new(media_key: "3_1880028106020515840")) # => "1880028106020515840"
      # @example The identifier a media key names
      #   Uploader::Utils.media_id("3_1880028106020515840") # => "1880028106020515840"
      def media_id(media)
        id = case media
        when Hash, UploadedMedia then media.fetch("id", nil)
        when String then media[MEDIA_KEY, 1] || media
        when Integer, nil then media
        else media_key_id(media)
        end
        text = id.to_s
        raise ArgumentError, NO_MEDIA_ID if text.empty?

        text.match?(MEDIA_ID) ? text : raise(ArgumentError, format(NOT_MEDIA_ID, text.inspect))
      end

      # The media identifier the media key of media names
      #
      # @api private
      # @param media [#media_key, Object] the media
      # @return [String, nil] the media identifier, or nil for media that has no media key
      # @raise [ArgumentError] if the media has no media_key, or its media key names no identifier
      # @example The identifier of media of a post
      #   Uploader::Utils.media_key_id(X::Media.new(media_key: "3_7")) # => "7"
      def media_key_id(media)
        raise ArgumentError, format(NOT_MEDIA, media.inspect) unless media.respond_to?(:media_key)

        key = media.media_key
        key && (key.to_s[MEDIA_KEY, 1] || raise(ArgumentError, format(NOT_MEDIA_KEY, key.inspect)))
      end

      # Media as uploaded media, which what an upload returned already is
      #
      # The Hash of an upload response is built into the uploaded media it describes, and media known by a media key or
      # by a media identifier into uploaded media that holds its identifier, and its media key if it has one.
      #
      # @api private
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, the upload response, media
      #   that has a media key, the media key, or the media identifier
      # @return [UploadedMedia] the uploaded media
      # @raise [ArgumentError] if the media is nil or empty, neither media, a media key, nor a media identifier, or its
      #   media key names none
      # @example Uploaded media known by its identifier
      #   Uploader::Utils.uploaded_media(7) # => #<X::UploadedMedia id=7 media_key=nil state=nil>
      def uploaded_media(media)
        case media
        when UploadedMedia then media
        when Hash then UploadedMedia.new(media)
        else
          keyed = media #: untyped
          UploadedMedia.new({"id" => media_id(media), "media_key" => (keyed.media_key if keyed.respond_to?(:media_key))}.compact)
        end
      end

      # The media metadata was added to, once the response says it was added
      #
      # The API answers a change of metadata with the media identifier and the metadata it now holds, under the data
      # of the response, which a response that succeeded without it does not say were added.
      #
      # @api private
      # @param response [Hash, nil] the parsed response body, or nil for a response without one
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the media the metadata was added to
      # @return [UploadedMedia] the media, as uploaded media
      # @raise [MissingMediaData] if the response holds no metadata
      # @example The media alt text was added to
      #   Uploader::Utils.described({"data" => {"id" => "7"}}, media) # => media
      def described(response, media)
        raise MissingMediaData.new(NO_METADATA, problems: Problem.all_from(response)) unless Hash.try_convert(response.to_h["data"])

        uploaded_media(media)
      end

      # The media a response of an upload describes
      #
      # The API answers an upload with what it acted on, under the data of the response, which always holds the
      # identifier of the media. A response that succeeded without it describes no media, whether it carries no body
      # at all, a body without data, or data whose identifier is missing, nil, or empty, so it raises rather than
      # leave the upload to fail later on what is missing, or return media that cannot be attached for media the API
      # may have billed. What it returns holds an identifier, so media that holds none was given by the caller.
      #
      # @api private
      # @param response [Hash, nil] the parsed response body, or nil for a response without one
      # @param description [String] how the error names the response, for its message
      # @return [Hash] the media
      # @raise [MissingMediaData] if the response holds no media, or media without an identifier
      # @example The media an upload returned
      #   Uploader::Utils.media_data({"data" => {"id" => 7}}, "of the upload") # => {"id" => 7}
      def media_data(response, description)
        media = Hash.try_convert(response.to_h["data"])
        return media if media && identified?(media)

        raise MissingMediaData.new(format(NO_MEDIA, description), problems: Problem.all_from(response))
      end

      # Upload media in a single request
      #
      # An image is uploaded so, as is a GIF a single request takes.
      #
      # @api private
      # @param client [Client] the X API client
      # @param content [String] the whole of the media, once its category is known to take it
      # @param media_category [String] the media category, in lowercase
      # @return [UploadedMedia] the uploaded media, which holds the upload response
      # @raise [MissingMediaData] if the response holds no media, or carries no body at all
      # @example Upload an image
      #   Uploader::Utils.single_request(client, png, "tweet_image")
      def single_request(client, content, media_category)
        UploadedMedia.new(media_data(Multipart.post(client, "media/upload", "media", content, media_category:), "of the upload"))
      end

      # Check whether media the API answered with holds an identifier
      #
      # An identifier of nil, or an empty one, is none.
      #
      # @api private
      # @param media [Hash{String => Object}] the media, as the data of a response
      # @return [Boolean] true if the media holds an identifier
      # @example Media whose identifier is nil
      #   Uploader::Utils.identified?({"id" => nil}) # => false
      def identified?(media) = !media.fetch("id", nil).to_s.empty?

      # Send a request again after a server or network error, as an idempotent one is
      #
      # A client sends no POST again, since the API may have acted on one whose answer never arrived, but some of
      # the POSTs of an upload have the same effect sent twice as sent once, such as a chunk, which names the segment
      # it is appended at. Those are sent again with the with_retries of the client, up to its max_retries, after the
      # wait a failed response asks for, or a backoff that grows with each retry and is cut short at random, so that
      # the requests one failure ended are not sent again together. They are sent again after a timeout too, which a
      # client sends no read again after, since the API bills an upload for nothing it sends twice. with_retries is
      # private to a client, since it is internal to the gems of x, and a client that has none, which X::Client has,
      # sends each request as it sends any other.
      #
      # @api private
      # @param client [Client] the X API client
      # @yield sends the request
      # @return [Object] what the block returns
      # @example Append a chunk, again after a failure
      #   Uploader::Utils.sending_again(client) { client.post("media/upload/1/append", body, headers:) }
      def sending_again(client, &)
        retrying = client #: untyped
        retrying.respond_to?(:with_retries, true) ? retrying.__send__(:with_retries, &) : yield
      end

      # The processing status of media, unless the media failed to process
      #
      # Media whose processing names no state, or a state X does not document, is neither processing nor ready, and
      # X gives no time to check it again at, so it raises too, naming the state, rather than be returned as media a
      # post can attach.
      #
      # @api private
      # @param status [UploadedMedia] the processing status X reported, or the response of an upload
      # @return [UploadedMedia] the status, of media that has processed, is still processing, or needs no processing
      # @raise [MediaProcessingFailed] if the media failed to process, or is in no state X documents, with the status
      # @example The status of media that has processed
      #   Uploader::Utils.processed!(status) # => status
      def processed!(status)
        raise MediaProcessingFailed.new(media: status) if status.failed?
        raise MediaProcessingFailed.new(format(UNKNOWN_STATE, status.state.inspect), media: status) unless status.ready? || status.processing?

        status
      end

      # Wait as long as the status of media still processing asks
      #
      # It waits at least a second, and gives up, rather than sleep, when the check would come after the deadline.
      #
      # @api private
      # @param status [UploadedMedia] the status of the media, which is still processing
      # @param deadline [Float] the time on the monotonic clock to give up at
      # @param timeout [Integer, Float] the seconds the deadline was set from, which the error names
      # @return [void]
      # @raise [MediaProcessingTimeout] if the check would come after the deadline
      # @example Wait before checking the status of media again
      #   Uploader::Utils.wait_to_check(status, deadline: Uploader::Utils.seconds_from_now(600), timeout: 600)
      def wait_to_check(status, deadline:, timeout:)
        wait = [status.check_after_secs.to_i, MIN_CHECK_AFTER_SECS].max
        raise MediaProcessingTimeout.new(media: status, timeout:) if seconds_from_now(wait) > deadline

        sleep wait
      end

      # The time on the monotonic clock some seconds from now, which keeps a deadline
      #
      # The monotonic clock counts from no time in particular, but never goes back, as the time of day does when the
      # clock of the system is set, so the seconds between two of its times are the seconds that passed between them.
      #
      # @api private
      # @param seconds [Integer, Float] the seconds from now, or Float::INFINITY for a time never reached
      # @return [Float] the time on the monotonic clock
      # @example The time on the monotonic clock a minute from now
      #   Uploader::Utils.seconds_from_now(60) # => 1234.5
      def seconds_from_now(seconds) = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds

      # The media category the subtitles endpoint takes, from one given in any form
      #
      # The uploaders take a category as tweet_video, in any case, and the endpoint names it TweetVideo, so both are
      # taken, and any other category raises before a request the endpoint would refuse.
      #
      # @api private
      # @param media_category [String, Symbol] the media category, in any form
      # @return [String] the media category as the subtitles endpoint names it
      # @raise [ArgumentError] if the media category is neither tweet_video nor amplify_video
      # @example The category of subtitles for a video attached to a post
      #   Uploader::Utils.subtitled_media_category(:tweet_video) # => "TweetVideo"
      def subtitled_media_category(media_category)
        key = media_category.to_s.sub(/([a-z])([A-Z])/, '\1_\2').downcase
        SUBTITLED_MEDIA_CATEGORIES.fetch(key) do
          raise ArgumentError, "Invalid media_category: #{media_category}. Valid values: #{SUBTITLED_MEDIA_CATEGORIES.keys.join(", ")}"
        end
      end
    end
    private_constant :Utils
  end
end
