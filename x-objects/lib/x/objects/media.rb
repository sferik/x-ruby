require_relative "resource"

module X
  # A photo, video, or animated GIF attached to a post
  # @api public
  class Media < Objects::Resource
    # Every public media field
    FIELDS = %w[alt_text duration_ms height media_key preview_image_url public_metrics type url variants width].freeze

    # The attribute holding the identifier
    #
    # @api private
    # @return [String] the identifier key
    # @example Get the identifier key
    #   X::Media.id_key # => "media_key"
    def self.id_key
      "media_key"
    end

    # The type of the identifier, which is not a number
    #
    # @api private
    # @return [Symbol] raw
    # @example Get the identifier type
    #   X::Media.id_type # => :raw
    def self.id_type = :raw

    # The key under which media appear in the includes of a response
    #
    # @api private
    # @return [String] the includes key
    # @example Get the includes key
    #   X::Media.includes_key # => "media"
    def self.includes_key
      "media"
    end

    # @!attribute [r] media_key
    #   The media key
    #   @api public
    #   @return [String] the media key
    #   @example Get the media key
    #     media.media_key
    attribute :media_key

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
    #   @return [Array<Hash>, nil] the variants
    #   @example Get the variants
    #     media.variants
    attribute :variants

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
