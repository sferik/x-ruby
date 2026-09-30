# frozen_string_literal: true

require_relative "batch_finders"
require_relative "media_ids"
require_relative "resource"

module X
  # A photo, video, or animated GIF attached to a post, which its media key identifies
  # @api public
  class Media < Resource
    extend Objects::BatchFinders

    # Every public media field
    #
    # A minor release may add to it the fields the API adds, so that a lookup asks for them too; see
    # {Resource#hydrated?} for what that means for a resource looked up with a list of fields of its own.
    FIELDS = %w[alt_text duration_ms height media_key preview_image_url public_metrics type url variants width].freeze

    # The attribute holding the identifier
    #
    # @api private
    # @return [String] the identifier key
    # @example Get the identifier key
    #   X::Media.__send__(:id_key) # => "media_key"
    def self.id_key
      "media_key"
    end

    # The lookup endpoint
    #
    # @api private
    # @return [String] the endpoint
    # @example Get the lookup endpoint
    #   X::Media.__send__(:endpoint) # => "media"
    def self.endpoint
      "media"
    end

    # The query parameter a batch lookup takes the media keys in
    #
    # @api private
    # @return [Symbol] the parameter name
    # @example Get the parameter of a batch lookup
    #   X::Media.__send__(:batch_key) # => :media_keys
    def self.batch_key = :media_keys

    # The name of the fields parameter
    #
    # @api private
    # @return [String] the fields parameter
    # @example Get the fields parameter
    #   X::Media.__send__(:fields_key) # => "media.fields"
    def self.fields_key = "media.fields"

    # The default query parameters requesting every public field
    #
    # @api public
    # @return [Hash{String => Array<String>}] the default query parameters
    # @example Get the default fields
    #   X::Media.default_params["media.fields"]
    def self.default_params
      {"media.fields" => FIELDS}
    end

    # The type of the identifier, a media key
    #
    # Media is looked up by its media key, such as "3_1880028106020515840", and not by the numeric identifier an
    # upload returns beside it, which the lookup endpoint does not find, so a number raises rather than look up
    # nothing.
    #
    # @api private
    # @return [Symbol] media_key
    # @example Get the identifier type
    #   X::Media.__send__(:id_type) # => :media_key
    def self.id_type = :media_key

    # The media key of what an upload returned, or of a value that is one already
    #
    # What an upload returns holds both a media key and a numeric identifier, and the lookup endpoint takes the
    # media key, so this reads that rather than the identifier a resource is usually found by.
    #
    # @api private
    # @param media [#media_key, String] the media, or its media key
    # @return [Object] the media key
    # @example Get the media key of an upload
    #   X::Media.__send__(:key_of, uploaded) # => "3_1880028106020515840"
    def self.key_of(media) = media.respond_to?(:media_key) ? media.media_key : media

    # Look up media by media key
    #
    # @api public
    # @param media [#media_key, String, Media] the media key, what an upload returned, or media
    # @param client [Object] the client used to make the request
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Media, nil] the media, or nil if it was not found
    # @yieldparam problem [Problem] each problem the API reported
    # @example Look up what an upload returned
    #   X::Media.find(uploaded, client: client)
    def self.find(media, client:, **params) = super(key_of(media), client:, **params) #: Media?

    # Look up media by media key, which must exist
    #
    # The error it raises names the media key looked up, whether a media key, what an upload returned, or media was
    # given.
    #
    # @api public
    # @param media [#media_key, String, Media] the media key, what an upload returned, or media
    # @param client [Object] the client used to make the request
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Media] the media
    # @raise [MissingResource] if the media was not found
    # @example Look up what an upload returned
    #   X::Media.find!(uploaded, client: client)
    def self.find!(media, client:, **params) = super(key_of(media), client:, **params) #: Media

    # Refer to media by media key without a request
    #
    # @api public
    # @param media [#media_key, String, Media] the media key, what an upload returned, or media
    # @param client [Object, nil] the client used to fetch the media
    # @return [Media] a stub that hydrates to the full media
    # @example Refer to what an upload returned
    #   X::Media.from_id(uploaded, client: client).hydrate.url
    def self.from_id(media, client: nil) = super #: Media

    # Build a stub of media that hydrates with the stubs of a batch
    #
    # @api private
    # @param media [#media_key, String, Media] the media key, what an upload returned, or media
    # @param client [Object, nil] the client used to fetch the media
    # @param batch [Objects::Batch, nil] the batch the stub hydrates with
    # @return [Media] a stub that hydrates to the full media
    # @example Build the stub of a page of media
    #   X::Media.__send__(:from_id_in_batch, "3_1", client: client, batch: batch)
    def self.from_id_in_batch(media, client:, batch: nil) = super(key_of(media), client:, batch:)

    # Look up many media by media key, in parallel batches
    #
    # @api public
    # @param media [Array<#media_key, String, Media>] the media keys, what the uploads returned, or media
    # @param client [Object] the client used to make the requests
    # @param params [Hash] query parameters merged over the default parameters, and the concurrency of the batches
    # @return [Array<Media>] the media that was found
    # @yieldparam problem [Problem] each problem the API reported
    # @example Look up what the uploads returned
    #   X::Media.find_all(uploads, client: client)
    def self.find_all(media, client:, concurrency: Objects::BatchFinders::DEFAULT_CONCURRENCY, **params) = super(media.map { |value| key_of(value) }, client:, concurrency:, **params) #: Array[Media]

    # The key under which media appear in the includes of a response
    #
    # @api private
    # @return [String] the includes key
    # @example Get the includes key
    #   X::Media.__send__(:includes_key) # => "media"
    def self.includes_key
      "media"
    end
    private_class_method :id_key, :endpoint, :batch_key, :fields_key, :id_type, :key_of, :from_id_in_batch, :includes_key

    # @!method id
    #   The identifier of the media, which is its media key
    #
    #   Media is looked up by its media key, so that is what identifies it here, where the identifier of uploaded
    #   media, and the one a post or a direct message attaches media by, is the number media_id reads. Both X::Media
    #   and the uploaded media of x-uploader answer media_key and media_id alike.
    #
    #   @api public
    #   @return [String] the media key
    #   @example Get the media key
    #     media.id # => "3_1880028106020515840"

    # @!attribute [r] media_key
    #   The media key
    #   @api public
    #   @return [String] the media key
    #   @example Get the media key
    #     media.media_key
    attribute :media_key

    # The numeric identifier of the media, which its media key names
    #
    # A media key names the identifier after the number of the type of the media and an underscore. It is the
    # identifier an upload returns, and the one a post or a direct message attaches media by.
    #
    # @api public
    # @return [Integer] the media identifier
    # @example Get the identifier the media key names
    #   X::Media.from_id("3_1880028106020515840").media_id # => 1880028106020515840
    def media_id = Integer(Objects::MediaIds.media_key_id(self), 10)

    # @!attribute [r] type
    #   The media type: photo, video, or animated_gif
    #   @api public
    #   @return [String, nil] the media type
    #   @example Get the type
    #     media.type
    attribute :type

    # @!attribute [r] url
    #   The URL of a photo
    #   @api public
    #   @return [String, nil] the URL
    #   @example Get the URL
    #     media.url
    attribute :url

    # @!attribute [r] preview_image_url
    #   The URL of a video or GIF preview image
    #   @api public
    #   @return [String, nil] the preview image URL
    #   @example Get the preview image URL
    #     media.preview_image_url
    attribute :preview_image_url

    # @!attribute [r] alt_text
    #   The alternative text
    #   @api public
    #   @return [String, nil] the alternative text
    #   @example Get the alternative text
    #     media.alt_text
    attribute :alt_text

    # @!attribute [r] duration_ms
    #   The duration of a video in milliseconds
    #   @api public
    #   @return [Integer, nil] the duration in milliseconds
    #   @example Get the duration
    #     media.duration_ms
    attribute :duration_ms

    # @!attribute [r] height
    #   The height in pixels
    #   @api public
    #   @return [Integer, nil] the height in pixels
    #   @example Get the height
    #     media.height
    attribute :height

    # @!attribute [r] width
    #   The width in pixels
    #   @api public
    #   @return [Integer, nil] the width in pixels
    #   @example Get the width
    #     media.width
    attribute :width

    # @!attribute [r] variants
    #   The video variants with their bit rates, content types, and URLs
    #   @api public
    #   @return [Array<Hash>] the variants, empty if there are none
    #   @example Get the variants
    #     media.variants
    attribute :variants, :list

    # @!attribute [r] public_metrics
    #   The public metrics
    #   @api public
    #   @return [Hash, nil] the public metrics
    #   @example Get the public metrics
    #     media.public_metrics
    attribute :public_metrics

    # @!attribute [r] view_count
    #   The number of views
    #   @api public
    #   @return [Integer, nil] the view count
    #   @example Get the view count
    #     media.view_count
    attribute :view_count, key: %w[public_metrics view_count]
  end
end
