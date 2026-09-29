# frozen_string_literal: true

require "json"
require "x/core/errors/unsupported_marshal_format"
require_relative "missing_media_data"

module X
  # Media that was uploaded: the response of an upload, or the status of its processing
  #
  # Both hold the identifier and the media key, and the status of media that X processes, such as a video, holds
  # the state of its processing. The object is frozen, and reads as the Hash it was built from with [], fetch,
  # dig, key?, and to_json, so media["size"] works as it did when an upload returned a Hash.
  #
  # The attributes hold the response as it arrived, so media["id"] is the String X sent, and the media writes itself
  # as JSON with the identifier a String, which a reader of JSON that holds numbers as floats reads whole. The
  # identifier is read as an Integer by id alone, as a resource of the object layer reads its own.
  #
  # @api public
  class UploadedMedia
    # The states of processing that has not ended, which X asks to be checked again
    PROCESSING_STATES = %w[pending in_progress].freeze
    # The message of the error raised for media that holds no identifier
    NO_MEDIA_ID = "The media holds no identifier"
    # The number of the format of the state Marshal writes, which a release that changes the format raises
    MARSHAL_FORMAT = 1
    private_constant :PROCESSING_STATES, :NO_MEDIA_ID, :MARSHAL_FORMAT

    # The response data the media was built from
    # @api public
    # @return [Hash{String => Object}] the frozen attributes
    # @example Get the attributes
    #   media.attrs # => {"id" => "1880028106020515840", "media_key" => "3_1880028106020515840", ...}
    attr_reader :attrs
    alias_method :to_h, :attrs

    # Build media from the data of a response, if it has any
    #
    # @api public
    # @param attrs [Hash{String => Object}, nil] the data of an upload or status response
    # @return [UploadedMedia, nil] the media, or nil for a response without data
    # @example Build media from a response
    #   X::UploadedMedia.from(client.post("media/upload", body)&.fetch("data"))
    def self.from(attrs)
      new(attrs) unless attrs.nil?
    end

    # Initialize uploaded media
    #
    # @api public
    # @param attrs [Hash{String => Object}] the data of an upload or status response
    # @return [UploadedMedia] a new, frozen instance
    # @example Refer to media that was uploaded before
    #   X::UploadedMedia.new({"id" => "1880028106020515840"})
    def initialize(attrs)
      @attrs = deep_freeze(attrs)
      freeze
    end

    # The numeric media ID, which a post attaches the media by
    #
    # It is the media ID the upload endpoints and a new post take, which {media_id} reads too. The X::Media of
    # x-objects, the media of a post as the object layer reads it, is identified by its media key instead, so its id
    # is the media key, which {media_key} reads here; both classes answer media_id and media_key alike.
    #
    # @api public
    # @return [Integer] the media ID, whether the response held it as a String or an Integer
    # @raise [MissingMediaData] if the response held no id
    # @raise [ArgumentError] if the response held an id that names no number
    # @example Get the media ID
    #   media.id # => 1880028106020515840
    def id = Integer(fetch("id") { raise MissingMediaData, NO_MEDIA_ID }.to_s, 10)

    # The numeric media ID, as the X::Media of x-objects names it
    #
    # It is the same as {id}, under the name that reads the same on uploaded media and on the media of a post.
    #
    # @api public
    # @return [Integer] the media ID, whether the response held it as a String or an Integer
    # @raise [MissingMediaData] if the response held no id
    # @raise [ArgumentError] if the response held an id that names no number
    # @example Get the media ID
    #   media.media_id # => 1880028106020515840
    def media_id = id

    # The media key, which names the type of the media and its media ID
    #
    # @api public
    # @return [String, nil] the media key, if the response holds one
    # @example Get the media key
    #   media.media_key # => "3_1880028106020515840"
    def media_key = self["media_key"]

    # The size of the media in bytes
    #
    # @api public
    # @return [Integer, nil] the size, if the response reports it
    # @example Get the size
    #   media.bytesize # => 1048576
    def bytesize = self["size"]

    # The seconds after the response within which the media can be attached to a post
    #
    # X counts them from when it sent the response, which the media does not hold, so they are read as X reported
    # them: media rebuilt from its attributes later, as from JSON it was stored as, holds the seconds of the response
    # it was built from, not those it has left.
    #
    # @api public
    # @return [Integer, nil] the seconds, if the response reports them
    # @example Get the time after which media just uploaded can no longer be attached
    #   Time.now + media.expires_after_secs # => 2026-09-19 12:00:00 -0700
    def expires_after_secs = self["expires_after_secs"]

    # What X reports of the processing of the media
    #
    # @api public
    # @return [Hash{String => Object}, nil] the processing information, or nil for media X does not process
    # @example Get the error of media that failed to process
    #   media.processing_info&.dig("error", "message")
    def processing_info = self["processing_info"]

    # The state of the processing of the media
    #
    # @api public
    # @return [String, nil] pending, in_progress, succeeded, or failed, or nil for media X does not process
    # @example Get the state
    #   media.state # => "succeeded"
    def state = dig("processing_info", "state")

    # The seconds X asks to wait before checking the processing again
    #
    # @api public
    # @return [Integer, nil] the seconds, if X asks for a wait
    # @example Get the wait
    #   media.check_after_secs # => 5
    def check_after_secs = dig("processing_info", "check_after_secs")

    # Check whether X is still processing the media
    #
    # Media is still processing in the states X asks to be checked again in, pending and in_progress, alone. Media
    # whose processing information names no state, or a state X does not document, is not, since X gives no time to
    # check it again at, and it is not ready either.
    #
    # @api public
    # @return [Boolean] true if the processing of the media is pending or in progress
    # @example Check whether a video is still processing
    #   media.processing?
    def processing? = PROCESSING_STATES.include?(state)

    # Check whether the processing of the media failed
    #
    # @api public
    # @return [Boolean] true if the processing failed
    # @example Check whether a video failed to process
    #   media.failed?
    def failed? = state.eql?("failed")

    # Check whether the media can be attached to a post
    #
    # Media whose processing information names no state, or a state X does not document, is not ready, since X has
    # not said that its processing succeeded.
    #
    # @api public
    # @return [Boolean] true if X does not process the media, or its processing succeeded
    # @example Check whether a video can be posted
    #   media.ready?
    def ready? = processing_info.nil? || state.eql?("succeeded")

    # Read an attribute of the response, as from the Hash an upload used to return
    #
    # @api public
    # @param key [String] the name of the attribute
    # @return [Object, nil] the value, or nil if the response holds none
    # @example Get the identifier
    #   media["id"] # => "1880028106020515840"
    def [](key) = attrs[key]

    # Fetch an attribute of the response, as from the Hash an upload used to return
    #
    # @api public
    # @param key [String] the name of the attribute
    # @param default [Array<Object>] the value to return for an attribute the response does not hold, if any
    # @yieldparam key [String] the name of an attribute the response does not hold
    # @yieldreturn [Object] the value to return in its place
    # @return [Object] the value
    # @raise [KeyError] if the response holds no such attribute and neither a default nor a block is given
    # @example Fetch the identifier
    #   media.fetch("id") # => "1880028106020515840"
    # @example Fetch what a response may hold none of
    #   media.fetch("processing_info", nil)
    def fetch(key, *default, &) = attrs.fetch(key, *default, &) # steep:ignore UnresolvedOverloading

    # Read a nested attribute of the response
    #
    # @api public
    # @param keys [Array<String, Integer>] the names that lead to the attribute
    # @return [Object, nil] the value, or nil if the response holds none
    # @example Get the state of the processing
    #   media.dig("processing_info", "state") # => "succeeded"
    def dig(*keys) = attrs.dig(*keys)

    # Check whether the response holds an attribute
    #
    # @api public
    # @param key [String] the name of the attribute
    # @return [Boolean] true if the response holds the attribute, whatever its value
    # @example Check whether X processes the media
    #   media.key?("processing_info")
    def key?(key) = attrs.key?(key)

    # The attributes of the response, as an encoder asks of an object of its own
    #
    # @api public
    # @return [Hash{String => Object}] the frozen attributes
    # @example Store the response of an upload beside a record of it
    #   record.update(upload: media.as_json)
    def as_json(*) = attrs

    # The attributes of the response as JSON
    #
    # Media written into the body of a request is the response it holds, rather than the object itself.
    #
    # @api public
    # @param state [JSON::State, nil] the state the encoder generating the JSON around it passes
    # @return [String] the JSON of the attributes
    # @example Attach the media to a post
    #   client.post("tweets", {text: "Look at this cat", media: {media_ids: [media.id.to_s]}})
    def to_json(state = nil) = as_json.to_json(state)

    # Check whether another object is the same uploaded media
    #
    # @api public
    # @param other [Object] the object to compare
    # @return [Boolean] true if the other object is uploaded media with the same attributes
    # @example Compare media
    #   media == X::UploadedMedia.new(media.to_h) # => true
    def ==(other) = other.instance_of?(self.class) && attrs.eql?(other.attrs)
    alias_method :eql?, :==

    # The hash code of the media, which equal media share
    #
    # @api public
    # @return [Integer] the hash code
    # @example Count the media uploaded
    #   uploads.uniq.size
    def hash = [self.class, attrs].hash

    # Summarize the media for the console
    #
    # @api public
    # @return [String] the class name, identifier, media key, and state
    # @example Inspect media
    #   media.inspect # => #<X::UploadedMedia id=1880028106020515840 media_key="3_1880028106020515840" state=nil>
    def inspect = "#<#{self.class} id=#{self["id"] || "nil"} media_key=#{media_key.inspect} state=#{state.inspect}>"

    # The state Marshal writes
    #
    # What is written is plain data, led by the number of its format, so that media written by one release of 1.x is
    # read by a later one: its attributes, as the response held them.
    #
    # @api public
    # @return [Array(Integer, Hash{String => Object})] the number of the format, then the attributes
    # @example Cache what an upload returned, to attach it later
    #   Rails.cache.write("upload", client.upload_media("image.png"))
    def marshal_dump = [MARSHAL_FORMAT, attrs]

    # Restore media Marshal read, built as the constructor builds it, deep-frozen
    #
    # @api public
    # @param state [Array] the state Marshal wrote
    # @return [void]
    # @raise [UnsupportedMarshalFormat] if the state is of a format this release does not read
    # @example Read what an upload returned from a cache
    #   Marshal.load(Marshal.dump(media)).media_key
    def marshal_load(state)
      format, attrs = state
      raise UnsupportedMarshalFormat, "#{self.class} reads format #{MARSHAL_FORMAT} of Marshal, not #{format.inspect}" unless MARSHAL_FORMAT.eql?(format)

      initialize(attrs)
    end

    private

    # Copy and freeze a value of a response, and what it holds
    # @api private
    # @param value [Object] the value
    # @return [Object] the frozen copy
    def deep_freeze(value)
      case value
      when Hash then value.transform_values { |element| deep_freeze(element) }.freeze
      when Array then value.map { |element| deep_freeze(element) }.freeze
      when String then value.dup.freeze
      else value
      end
    end
  end
end
