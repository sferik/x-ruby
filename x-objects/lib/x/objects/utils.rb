# frozen_string_literal: true

require "time"
require "uri"

module X
  module Objects
    # Helpers shared across the object layer
    # @api private
    module Utils
      # Parsing options that make a client return plain hashes and arrays, whatever its defaults
      JSON_CLASSES = {array_class: Array, object_class: Hash}.freeze

      # The pattern of an identifier that is a number, which most resources are identified by
      NUMERIC_ID = /\A\d+\z/

      # The pattern of an identifier that is not a number: the word characters a space identifier and a media key are
      # written with, or the two numbers a one-to-one conversation identifier joins with a hyphen
      RAW_ID = /\A(?:\w+|\d+-\d+)\z/

      # The pattern of a username: one to fifteen word characters, which the at sign a handle is often written with
      # may precede
      USERNAME = /\A@?\w{1,15}\z/

      extend self

      # Return a deep-frozen copy of a value with string keys
      #
      # @api private
      # @param value [Object] the value to copy and freeze
      # @return [Object] the frozen copy
      def deep_freeze(value)
        case value
        when Hash then value.transform_keys(&:to_s).transform_values { |element| deep_freeze(element) }.freeze
        when Array then value.map { |element| deep_freeze(element) }.freeze
        when String then value.dup.freeze
        else value
        end
      end

      # Build an endpoint path with an encoded query string
      #
      # @api private
      # @param base [String] the endpoint path without a query string
      # @param params [Hash] the query parameters
      # @return [String] the endpoint path with a query string
      def path(base, params)
        query = query(params)
        return base if query.empty?

        "#{base}?#{URI.encode_www_form(query)}"
      end

      # Normalize query parameters into string keys and comma-separated values
      #
      # @api private
      # @param params [Hash] the query parameters
      # @return [Hash{String => String, Integer}] the normalized parameters
      def query(params)
        params.transform_keys(&:to_s).compact.transform_values { |value| query_value(value) }
      end

      # Normalize a query parameter value
      #
      # An Array is joined with commas, and a Time is given in UTC in the ISO 8601 form the API takes.
      #
      # @api private
      # @param value [Object] the value
      # @return [Object] the normalized value
      def query_value(value)
        case value
        when Array then value.join(",")
        when Time then value.getutc.iso8601
        else value
        end
      end

      # Merge query parameters over defaults, dropping parameters set to nil
      #
      # @api private
      # @param defaults [Hash] the default query parameters
      # @param params [Hash] the query parameters to merge over the defaults
      # @return [Hash{String => String, Integer}] the normalized parameters
      def merge_params(defaults, params)
        query(defaults.merge(params))
      end

      # Extract an identifier from a resource or a raw value
      #
      # The identifiers of most resources are numbers, so a value that is not, such as a username, raises rather than
      # reach the API as an identifier it cannot be. The identifiers that are not numbers, such as those of spaces and
      # media, are word characters, so anything else raises rather than reach the API as part of a path.
      #
      # @api private
      # @param value [#id, String, Integer] a resource or an identifier
      # @param raw [Boolean] true for a resource whose identifiers are not numbers, such as a space
      # @return [String] the identifier
      # @raise [ArgumentError] if the identifier is not a number, or is not word characters when raw
      def id_of(value, raw: false)
        id = id_from(value)
        return id if id.match?(raw ? RAW_ID : NUMERIC_ID)

        raise ArgumentError, "#{value.inspect} is not an identifier: pass a resource, #{raw ? "or a String of word characters" : "an Integer, or a String of digits"}"
      end

      # The identifier a value carries, read from a resource or taken as it is
      #
      # The resource this builds checks the identifier when it is made, so this only reads one.
      #
      # @api private
      # @param value [#id, String, Integer] a resource or an identifier
      # @return [String] the identifier
      def id_from(value) = value.respond_to?(:id) ? value.id.to_s : value.to_s

      # Normalize a username, dropping the at sign a handle is often written with
      #
      # @api private
      # @param value [String] the username, with or without a leading at sign
      # @return [String] the username
      def username(value)
        value.to_s.delete_prefix("@")
      end

      # Normalize a username, which must be one, so nothing else reaches a path
      #
      # @api private
      # @param value [String] the username, with or without a leading at sign
      # @return [String] the username, without the at sign
      # @raise [ArgumentError] if the value is not one to fifteen word characters
      def username!(value)
        name = value.to_s
        return name.delete_prefix("@") if name.match?(USERNAME)

        raise ArgumentError, "#{value.inspect} is not a username: pass one to fifteen letters, digits, or underscores"
      end

      # The identifier of the user a client's credentials name, when they name one
      #
      # The client's authenticator is where a client keeps the credentials it signs with, and it answers the user
      # they act for; only an OAuth 1.0a access token names one, since it begins with the identifier of the user who
      # authorized it. The secrets a client signs with are its authenticator's to keep, so this asks for the user
      # rather than for a credential to read it out of.
      #
      # @api private
      # @param client [Object] the client, whose credentials may name a user
      # @return [Integer, nil] the identifier, or nil if the client's credentials name no user
      def authenticated_user_id(client)
        authenticator = authenticator_of(client)
        authenticator.user_id if authenticator.respond_to?(:user_id)
      end

      # The authenticator of a client, which is replaced whenever its credentials change
      #
      # @api private
      # @param client [Object] the client, which may have an authenticator
      # @return [Object, nil] the authenticator, or nil if the client has none
      def authenticator_of(client)
        client.authenticator if client.respond_to?(:authenticator)
      end

      # The client for an endpoint that takes app-only authentication
      #
      # @api private
      # @param client [Object] the client
      # @return [Object] the client's app-only client, which reuses its bearer token, or the client itself
      def app_client(client)
        client.respond_to?(:app_only) ? client.app_only : client
      end

      # Read a numeric identifier as an Integer
      #
      # @api private
      # @param value [String, Integer, nil] the identifier
      # @return [Integer, nil] the identifier or nil if it is missing
      def integer(value)
        Integer(value.to_s, 10) unless value.nil?
      end

      # Extract a media identifier from what an upload returned, or a raw value
      #
      # What an upload returns is read with fetch, which a Hash answers and so does the uploaded media of
      # x-uploader, which this gem does not depend on.
      #
      # @api private
      # @param value [#fetch, String, Integer] what an upload returned, holding an id, or an identifier
      # @return [String] the media identifier
      def media_id_of(value)
        case value
        when String, Integer then value.to_s
        else value.fetch("id").to_s
        end
      end

      # The media identifiers of one upload or of several
      #
      # One upload needs no array around it, so a single value is read as a list of one, and nil, like an empty
      # list, as none.
      #
      # @api private
      # @param media_ids [Array, #fetch, String, Integer, nil] what the uploads returned, or identifiers, one or many
      # @return [Array<String>] the media identifiers, empty for nil
      def media_ids_of(media_ids)
        case media_ids
        when nil then []
        when Array then media_ids.map { |media| media_id_of(media) }
        else [media_id_of(media_ids)]
        end
      end

      # Check whether a value identifies a resource rather than naming one
      #
      # An Integer is an identifier and a String is a name, such as a username, so that an
      # account whose username is all digits is looked up as the name it is.
      #
      # @api private
      # @param value [#id, String, Integer] a resource, an identifier, or a username
      # @return [Boolean] true if the value is a resource or an Integer identifier
      def id?(value)
        value.respond_to?(:id) || value.instance_of?(Integer)
      end

      # Parse an ISO 8601 timestamp
      #
      # @api private
      # @param value [String, nil] the timestamp
      # @return [Time, nil] the parsed time or nil if the timestamp is missing
      def time(value)
        Time.iso8601(value) unless value.nil?
      end
    end
  end
end
