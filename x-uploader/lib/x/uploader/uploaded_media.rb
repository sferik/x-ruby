# frozen_string_literal: true

require "json"

module X
  module Uploader
    # Media that was uploaded: the response of an upload, or the status of its processing
    #
    # Both hold the identifier and the media key, and the status of media that X processes, such as a video, holds
    # the state of its processing. The object is frozen, and reads as the Hash it was built from with [], fetch,
    # dig, key?, and to_json, so media["size"] works as it did when an upload returned a Hash.
    #
    # The identifier is read as an Integer, however the response held it, so that media["id"] and media.id are one
    # number rather than a String beside an Integer, and the attributes the media reads as, compares by, and writes
    # itself as hold that one value.
    #
    # @api public
    class UploadedMedia
      # The states of processing that has ended
      FINAL_STATES = %w[failed succeeded].freeze
      private_constant :FINAL_STATES

      # The response data the media was built from
      # @api public
      # @return [Hash{String => Object}] the frozen attributes
      # @example Get the attributes
      #   media.attrs # => {"id" => 1880028106020515840, "media_key" => "3_1880028106020515840", ...}
      attr_reader :attrs
      alias_method :to_h, :attrs

      # Build media from the data of a response, if it has any
      #
      # @api public
      # @param attrs [Hash{String => Object}, nil] the data of an upload or status response
      # @return [UploadedMedia, nil] the media, or nil for a response without data
      # @example Build media from a response
      #   X::Uploader::UploadedMedia.from(client.post("media/upload", body)&.fetch("data"))
      def self.from(attrs)
        new(attrs) unless attrs.nil?
      end

      # Initialize uploaded media
      #
      # @api public
      # @param attrs [Hash{String => Object}] the data of an upload or status response
      # @return [UploadedMedia] a new, frozen instance
      # @raise [ArgumentError] if the response held an id that names no number
      # @example Refer to media that was uploaded before
      #   X::Uploader::UploadedMedia.new({"id" => "1880028106020515840"})
      def initialize(attrs)
        @attrs = deep_freeze(with_integer_id(attrs))
        @received_at = Time.now
        freeze
      end

      # The media identifier, which a post attaches the media by
      #
      # @api public
      # @return [Integer] the identifier, whether the response held it as a String or an Integer
      # @raise [KeyError] if the response held no id
      # @example Get the identifier
      #   media.id # => 1880028106020515840
      def id = fetch("id")

      # The media key
      #
      # @api public
      # @return [String, nil] the media key
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

      # The time after which the media can no longer be attached to a post
      #
      # X reports the seconds the media has left, which are counted from when the response arrived, in UTC as the
      # times of the object layer are.
      #
      # @api public
      # @return [Time, nil] the expiration time, in UTC, if the response reports it
      # @example Get the expiration time
      #   media.expires_at # => 2026-09-19 12:00:00 UTC
      def expires_at
        self["expires_after_secs"]&.then { |seconds| (@received_at + seconds).utc }
      end

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
      # @api public
      # @return [Boolean] true if the media is processed and its processing has neither succeeded nor failed
      # @example Check whether a video is still processing
      #   media.processing?
      def processing? = !processing_info.nil? && !FINAL_STATES.include?(state)

      # Check whether the processing of the media failed
      #
      # @api public
      # @return [Boolean] true if the processing failed
      # @example Check whether a video failed to process
      #   media.failed?
      def failed? = state.eql?("failed")

      # Check whether the media can be attached to a post
      #
      # @api public
      # @return [Boolean] true if X does not process the media, or has processed it
      # @example Check whether a video can be posted
      #   media.ready?
      def ready? = !processing? && !failed?

      # Read an attribute of the response, as from the Hash an upload used to return
      #
      # @api public
      # @param key [String] the name of the attribute
      # @return [Object, nil] the value, or nil if the response holds none
      # @example Get the identifier
      #   media["id"] # => 1880028106020515840
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
      #   media.fetch("id") # => 1880028106020515840
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
      # @example Build the JSON of a post that attaches the media
      #   {media: {media_ids: [media.as_json]}}
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
      #   media == X::Uploader::UploadedMedia.new(media.to_h) # => true
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
      #   media.inspect # => #<X::Uploader::UploadedMedia id="1880028106020515840" media_key="3_1880028106020515840" state=nil>
      def inspect = "#<#{self.class} id=#{self["id"].inspect} media_key=#{media_key.inspect} state=#{state.inspect}>"

      private

      # The attributes, with the identifier read as an Integer
      #
      # The response holds the identifier as a String, or as an Integer where it was written by an encoder of its
      # own, and the attributes hold the one number either way.
      #
      # @api private
      # @param attrs [Hash{String => Object}] the data of an upload or status response
      # @return [Hash{String => Object}] the attributes, holding an identifier that is an Integer
      # @raise [ArgumentError] if the response held an id that names no number
      def with_integer_id(attrs)
        id = attrs["id"]
        id.nil? ? attrs : attrs.merge("id" => Integer(id.to_s, 10))
      end

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
end
