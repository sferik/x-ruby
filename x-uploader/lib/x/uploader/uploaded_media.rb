module X
  module Uploader
    # Media that was uploaded: the response of an upload, or the status of its processing
    #
    # Both hold the identifier and the media key, and the status of media that X processes, such as a video, holds
    # the state of its processing. The object is frozen, and reads as the Hash it was built from with [], fetch,
    # dig, and key?, so media["id"] works as it did when an upload returned a Hash.
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
      #   media.attrs # => {"id" => "1880028106020515840", "media_key" => "3_1880028106020515840", ...}
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
      # @example Refer to media that was uploaded before
      #   X::Uploader::UploadedMedia.new({"id" => "1880028106020515840"})
      def initialize(attrs)
        @attrs = deep_freeze(attrs)
        @received_at = Time.now
        freeze
      end

      # The media identifier, which a post attaches the media by
      #
      # @api public
      # @return [Integer] the identifier
      # @raise [KeyError] if the response held no id
      # @example Get the identifier
      #   media.id # => 1880028106020515840
      def id = Integer(fetch("id"), 10)

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
      #   media.size # => 1048576
      def size = self["size"]

      # The time after which the media can no longer be attached to a post
      #
      # X reports the seconds the media has left, which are counted from when the response arrived.
      #
      # @api public
      # @return [Time, nil] the expiration time, if the response reports it
      # @example Get the expiration time
      #   media.expires_at # => 2026-09-19 12:00:00 -0700
      def expires_at
        self["expires_after_secs"]&.then { |seconds| @received_at + seconds }
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
      # @example Get the identifier as the API gave it
      #   media["id"] # => "1880028106020515840"
      def [](key) = attrs[key]

      # Fetch an attribute of the response, raising if the response holds none
      #
      # @api public
      # @param key [String] the name of the attribute
      # @yieldparam key [String] the name of an attribute the response does not hold
      # @yieldreturn [Object] the value to return in its place
      # @return [Object] the value
      # @raise [KeyError] if the response holds no such attribute and no block is given
      # @example Fetch the identifier as the API gave it
      #   media.fetch("id") # => "1880028106020515840"
      def fetch(key)
        return attrs.fetch(key) if key?(key) || !block_given?

        yield key
      end

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
