# frozen_string_literal: true

require "json"
require "x/core"

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
    # The states of processing that has ended, in success or in failure; in any other, X is still processing the media
    ENDED_STATES = %w[succeeded failed].freeze
    # The attributes that name media, which media known by its identifier or media key alone holds, and nothing more
    IDENTIFYING_KEYS = %w[id media_key].freeze
    # The pattern of a media ID, as a String: one to nineteen digits, as the API takes it and the uploaders check it
    MEDIA_ID = /\A\d{1,19}\z/
    # The message of the error raised for media that holds no identifier
    NO_MEDIA_ID = "attrs must hold the \"id\" of the media, an Integer or a String of 1 to 19 digits, as an upload " \
      "returns it, not %s"
    # The number of the format of the state Marshal writes, which every release of 1.x writes
    #
    # A later release of 1.x adds to the state only what an earlier one ignores, parts after those it reads and keys of a
    # Hash it does not read, so that the state one release of 1.x writes is read by every other, earlier or later.
    MARSHAL_FORMAT = 1
    # The name YAML writes each part of the state under, in the order Marshal writes them
    YAML_KEYS = %w[format attrs].freeze
    # The type of each value of processing information the API documents, which a wait reads as a whole number
    PROCESSING_TYPES = {
      "state" => String, "error" => Hash, "check_after_secs" => ->(wait) { wait.is_a?(String) || (wait.is_a?(Numeric) && wait.finite?) }
    }.freeze
    private_constant :ENDED_STATES, :IDENTIFYING_KEYS, :MEDIA_ID, :NO_MEDIA_ID, :MARSHAL_FORMAT, :YAML_KEYS, :PROCESSING_TYPES

    # Check whether the data of a response is media the API documents
    #
    # It is an object that holds an identifier an upload can name, and processing information, if any, whose state,
    # wait, and error are of the types the API documents, so that the media can be read and waited for. Anything else,
    # data that is not an object or an identifier of nil among them, is none.
    #
    # Internal to x-uploads: an upload checks the media each response holds with it, called with __send__.
    #
    # @api private
    # @param data [Object] the data of a response
    # @return [Boolean, nil] true if the data is media the API documents, or false or nil if not
    # @example Media whose identifier is nil
    #   X::UploadedMedia.__send__(:documented?, {"id" => nil}) # => false
    def self.documented?(data)
      processing = new(data)["processing_info"]
      return true if processing.nil?

      Hash.try_convert(processing)&.then { |info| PROCESSING_TYPES.all? { |key, type| info[key].then { |value| value.nil? || type === value } } }
    rescue ArgumentError
      false
    end
    private_class_method :documented?

    # The response data the media was built from
    # @api public
    # @return [Hash{String => Object}] the frozen attributes
    # @example Get the attributes
    #   media.attrs # => {"id" => "1880028106020515840", "media_key" => "3_1880028106020515840", ...}
    attr_reader :attrs
    alias_method :to_h, :attrs

    # Initialize uploaded media
    #
    # The media must hold its identifier under the String key "id", as every upload and status response does, so that
    # the media can be attached to a post, and {id} raises for none.
    #
    # @api public
    # @param attrs [Hash{String => Object}] the data of an upload or status response
    # @return [UploadedMedia] a new, frozen instance
    # @raise [ArgumentError] if the attributes are not a Hash, or hold no "id" that is a media ID the API takes: an
    #   Integer that is not negative, or a String of digits alone, of 1 to 19 digits
    # @example Refer to media that was uploaded before
    #   X::UploadedMedia.new({"id" => "1880028106020515840"})
    def initialize(attrs)
      @attrs = deep_freeze(Hash.try_convert(attrs) || raise(ArgumentError, "attrs must be a Hash, not #{attrs.inspect}"))
      raise ArgumentError, format(NO_MEDIA_ID, self["id"].inspect) unless media_id?(self["id"])

      freeze
    end

    # The numeric media ID, which a post attaches the media by
    #
    # It is the media ID the upload endpoints and a new post take, which {media_id} reads too. The X::Media of
    # x-resources, the media of a post as the object layer reads it, is identified by its media key instead, so its id
    # is the media key, which {media_key} reads here; both classes answer media_id and media_key alike.
    #
    # It is read as strictly as x-resources reads an identifier: an Integer as it is, and a String of digits alone, with
    # no sign, underscore, or whitespace, as a decimal number, so that " 1_0 " is no identifier, rather than 10.
    #
    # @api public
    # @return [Integer] the media ID, whether the response held it as a String or an Integer
    # @example Get the media ID
    #   media.id # => 1880028106020515840
    def id
      value = fetch("id")
      value.instance_of?(Integer) ? value : Integer(value, 10)
    end

    # The numeric media ID, as the X::Media of x-resources names it
    #
    # It is the same as {id}, under the name that reads the same on uploaded media and on the media of a post.
    #
    # @api public
    # @return [Integer] the media ID, whether the response held it as a String or an Integer
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
    # @example Get how far X has processed the media
    #   media.processing_info&.fetch("progress_percent", nil)
    def processing_info = self["processing_info"]

    # The state of the processing of the media
    #
    # It is read as X reported it, so a state X adds, which this release knows nothing of, is read as any other.
    #
    # @api public
    # @return [String, nil] pending, in_progress, succeeded, failed, or any other state X reports, or nil for media X
    #   does not process
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
    # Media X processes is still processing until its processing ends, which it does in two states alone: succeeded,
    # which {ready?} tells, and failed, which {failed?} tells. In any other it is still processing, whether pending or
    # in_progress, a state X does not document, or no state at all, so that a state X adds between the two it has is
    # waited through as they are, rather than read as a failure. Media X does not process is not processing.
    #
    # @api public
    # @return [Boolean] true if X reports processing of the media that has neither succeeded nor failed
    # @example Check whether a video is still processing
    #   media.processing?
    def processing? = !(processing_info.nil? || ENDED_STATES.include?(state))

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
    # not said that its processing succeeded: it is still processing, as {processing?} tells. Neither is media that
    # holds its identifier and media key alone, as media built from an identifier does, such as the media add_alt_text
    # returns for one, since it holds no response of X to say whether X processes it; await_media_processing checks it.
    #
    # @api public
    # @return [Boolean] true if a response of X holds no processing of the media, or its processing succeeded
    # @example Check whether a video can be posted
    #   media.ready?
    def ready? = processing_info.nil? ? !attrs.except(*IDENTIFYING_KEYS).empty? : state.eql?("succeeded")

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
    def inspect = "#<#{self.class} id=#{id} media_key=#{media_key.inspect} state=#{state.inspect}>"

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
    # @raise [UnsupportedFormat] if the state is of a format this release does not read
    # @raise [ArgumentError] if the attributes of the state are not a Hash, or hold no "id" of the media
    # @example Read what an upload returned from a cache
    #   Marshal.load(Marshal.dump(media)).media_key
    def marshal_load(state)
      format, attrs = state
      raise UnsupportedFormat, "#{self.class} reads format #{MARSHAL_FORMAT} of Marshal, not #{format.inspect}" unless MARSHAL_FORMAT.eql?(format)

      initialize(attrs)
    end

    # Write the state Marshal writes as YAML
    #
    # YAML would write the instance variables of the media, and read them back into one that is not frozen, so it says
    # how it is written: each part of the state Marshal writes, under its name.
    #
    # @api public
    # @param coder [Psych::Coder] the coder YAML writes the media with
    # @return [void]
    # @example Write media as YAML
    #   YAML.dump(client.upload_media("image.png"))
    def encode_with(coder) = YAML_KEYS.zip(marshal_dump) { |key, value| coder[key] = value }

    # Restore media YAML read, frozen, as Marshal restores one
    #
    # @api public
    # @param coder [Psych::Coder] the coder YAML read the media with
    # @return [void]
    # @raise [UnsupportedFormat] if the state is of a format this release does not read
    # @example Read media written as YAML
    #   YAML.unsafe_load(YAML.dump(media)).media_key
    def init_with(coder) = marshal_load(coder.map.values_at(*YAML_KEYS))

    private

    # Check whether a value is a media ID the API takes
    #
    # It is an Integer, or a String, of 1 to 19 digits alone, so that an Integer that is negative, a String with a
    # sign, an underscore, or whitespace, and anything else whose to_s reads as digits, such as a Symbol, is none.
    #
    # @api private
    # @param value [Object] the value
    # @return [Boolean] true if the value is a media ID the API takes
    def media_id?(value) = (Integer === value || String === value) && MEDIA_ID.match?(value.to_s)

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
