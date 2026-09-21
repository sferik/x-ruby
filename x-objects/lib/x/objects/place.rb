# frozen_string_literal: true

require_relative "resource"

module X
  # A place tagged in a post
  # @api public
  class Place < Resource
    # Every public place field
    FIELDS = %w[contained_within country country_code full_name geo id name place_type].freeze

    # The type of the identifier, which is not a number
    #
    # @api private
    # @return [Symbol] raw
    # @example Get the identifier type
    #   X::Place.id_type # => :raw
    def self.id_type = :raw

    # The key under which places appear in the includes of a response
    #
    # @api private
    # @return [String] the includes key
    # @example Get the includes key
    #   X::Place.includes_key # => "places"
    def self.includes_key
      "places"
    end

    # @!attribute [r] name
    #   The short name
    #   @api public
    #   @return [String, nil] the short name
    #   @example Get the name
    #     place.name
    attribute :name

    # @!attribute [r] full_name
    #   The full name
    #   @api public
    #   @return [String, nil] the full name
    #   @example Get the full name
    #     place.full_name
    attribute :full_name

    # @!attribute [r] country
    #   The country name
    #   @api public
    #   @return [String, nil] the country name
    #   @example Get the country
    #     place.country
    attribute :country

    # @!attribute [r] country_code
    #   The ISO 3166-1 alpha-2 country code
    #   @api public
    #   @return [String, nil] the country code
    #   @example Get the country code
    #     place.country_code
    attribute :country_code

    # @!attribute [r] place_type
    #   The place type, such as city or poi
    #   @api public
    #   @return [String, nil] the place type
    #   @example Get the place type
    #     place.place_type
    attribute :place_type

    # @!attribute [r] contained_within
    #   The identifiers of the places containing this place
    #   @api public
    #   @return [Array<String>, nil] the containing place identifiers
    #   @example Get the containing places
    #     place.contained_within
    attribute :contained_within

    # @!attribute [r] geo
    #   The GeoJSON bounding box
    #   @api public
    #   @return [Hash, nil] the GeoJSON
    #   @example Get the GeoJSON
    #     place.geo
    attribute :geo
  end
end
