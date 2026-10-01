# frozen_string_literal: true

require "time"
require "uri"
require_relative "errors"

module X
  module Objects
    # Helpers shared across the object layer
    # @api private
    module Utils
      # Parsing options that make a client return plain hashes and arrays, whatever its defaults
      JSON_CLASSES = {array_class: Array, object_class: Hash}.freeze

      # The pattern of an identifier that is a number, which most resources are identified by
      NUMERIC_ID = /\A\d+\z/

      # The pattern of the identifiers of each type, as the id_type of a resource class names it: a number; the word
      # characters a space identifier is written with, or the two numbers a one-to-one conversation identifier joins
      # with a hyphen; and a media key, which is the number of the type of media and the numeric identifier of the
      # media, joined with an underscore
      ID_PATTERNS = {integer: NUMERIC_ID, raw: /\A(?:\w+|\d+-\d+)\z/, media_key: /\A\d+_\d+\z/}.freeze

      # What an identifier of each type is, which the error raised for one that is not names
      ID_DESCRIPTIONS = {integer: "an Integer, or a String of digits", raw: "or a String of word characters", media_key: "what an upload returned, or a media key, such as \"3_1880028106020515840\""}.freeze

      # The pattern of a username: one to fifteen word characters, which the at sign a handle is often written with
      # may precede
      USERNAME = /\A@?\w{1,15}\z/
      private_constant :ID_PATTERNS, :ID_DESCRIPTIONS, :USERNAME

      # The message of the error raised for a resource of another class than the one an identifier was expected of
      FOREIGN_RESOURCE = "%<given>s %<id>s is not %<expected>s: pass %<expected>s or its identifier"
      private_constant :FOREIGN_RESOURCE

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

      # The number of resources a count asks for, converted as Array#first converts it
      #
      # @api private
      # @param count [Object] the count
      # @return [Integer] the count, as an Integer
      # @raise [TypeError] if the count does not convert to an Integer
      # @example Read a count given as a Float
      #   X::Objects::Utils.count!(2.5) # => 2
      def count!(count) = Integer.try_convert(count) || raise(TypeError, "no implicit conversion of #{count.class} into Integer")

      # The attributes a public constructor is given, which must be a Hash
      #
      # Attributes that are not one, such as nil, would otherwise be taken, and raise NoMethodError from a reader, far
      # from where they were given.
      #
      # @api private
      # @param attrs [Hash] the attributes
      # @return [Hash] the attributes
      # @raise [ArgumentError] if the attributes are not a Hash
      # @example Refuse attributes that are not a Hash
      #   X::Objects::Utils.attributes!(nil) # raises ArgumentError
      def attributes!(attrs) = Hash.try_convert(attrs) || raise(ArgumentError, "attrs must be a Hash, not #{attrs.inspect}")

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

      # Extract the identifier of a resource of a class from the resource or a raw value
      #
      # The identifiers of most resources are numbers, so a value that is not, such as a username, raises rather than
      # reach the API as an identifier it cannot be. The identifiers that are not numbers, such as those of spaces, are
      # word characters, so anything else raises rather than reach the API as part of a path, and a media key is two
      # numbers joined with an underscore, so the numeric identifier of media raises rather than look up nothing. A
      # resource of another class raises too, since its identifier is one of another kind of resource, which the API
      # would read as the identifier of a resource of this class, such as a list followed as though it were a user.
      #
      # @api private
      # @param value [Resource, String, Integer] a resource or an identifier
      # @param klass [Class] the resource class the identifier is of
      # @return [String] the identifier
      # @raise [ArgumentError] if the value is a resource of another class, is neither a resource nor an identifier,
      #   or the identifier is not a number, or is not word characters for a resource whose identifiers are not
      #   numbers, such as a space, or is not a media key for media
      def id_of(value, klass)
        id = id_from(value, klass)
        return id if id.match?(ID_PATTERNS.fetch(klass.__send__(:id_type)))

        not_an_identifier(value, klass)
      end

      # The identifier a value carries, read from a resource or taken as it is
      #
      # The resource this builds checks the identifier when it is made, so this only reads one, and refuses a
      # resource of another class, whose identifier is not one of this class. Anything else that answers id, such as a
      # record of an application's database, is refused too, rather than send an identifier of its own to the API as
      # one of X.
      #
      # @api private
      # @param value [Resource, String, Integer] a resource or an identifier
      # @param klass [Class] the resource class the identifier is of
      # @return [String] the identifier
      # @raise [ArgumentError] if the value is a resource of another class, or is neither a resource nor an identifier
      def id_from(value, klass)
        return value.id.to_s if value.is_a?(klass)
        return value.to_s if value.is_a?(String) || value.instance_of?(Integer)
        raise ArgumentError, format(FOREIGN_RESOURCE, given: value.class, id: value.id, expected: klass) if value.is_a?(Resource)

        not_an_identifier(value, klass)
      end

      # Refuse a value that is not an identifier of a resource of a class
      #
      # @api private
      # @param value [Object] the value
      # @param klass [Class] the resource class the identifier is of
      # @return [void]
      # @raise [ArgumentError] always
      def not_an_identifier(value, klass)
        raise ArgumentError, "#{value.inspect} is not an identifier: pass #{klass}, #{ID_DESCRIPTIONS.fetch(klass.__send__(:id_type))}"
      end

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
      # rather than for a credential to read it out of. An authenticator of another's making may answer the identifier
      # as the String of digits it read off a token, so it is read as an Integer, as every identifier is, and compared
      # with the identifiers of users as one.
      #
      # @api private
      # @param client [Object] the client, whose credentials may name a user
      # @return [Integer, nil] the identifier, or nil if the client's credentials name no user
      # @raise [ArgumentError] if the authenticator answers a user_id that is not an identifier
      def authenticated_user_id(client)
        authenticator = authenticator_of(client)
        integer(authenticator.user_id) if authenticator.respond_to?(:user_id)
      end

      # The identifier of the user a lookup found for a client's credentials
      #
      # It is kept on the client in an instance variable named for this gem, since any class can include
      # X::Objects::API, and one named @current_user_id, as an application often names its own, would be overwritten.
      #
      # @api private
      # @param client [Object] the client
      # @return [Integer, nil] the identifier, or nil if none was found for the authenticator the client holds
      def remembered_user_id(client)
        owner, id = client.instance_variable_get(:@x_objects_current_user_id)
        id if owner.equal?(authenticator_of(client))
      end

      # Keep the identifier of the authenticated user, with the authenticator
      #
      # A frozen client keeps nothing.
      #
      # @api private
      # @param client [Object] the client
      # @param id [Integer] the identifier
      # @return [void]
      def remember_user_id(client, id)
        client.instance_variable_set(:@x_objects_current_user_id, [authenticator_of(client), id]) unless client.frozen?
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

      # The client for an endpoint that refuses OAuth 1.0a, as a space endpoint does
      #
      # The endpoint takes app-only or OAuth 2.0 user authentication, as the count of recent posts does too.
      # A client that signs with OAuth 1.0a requests as the app, with a copy that reuses its bearer token, as one
      # signed in with OAuth 2.0 as a user that holds the app's credentials does. One that holds none, and so has no
      # app-only client, requests as the user.
      #
      # @api private
      # @param client [Object] the client
      # @return [Object] the client's app-only client, or the client itself
      def space_client(client)
        app_client(client)
      rescue UnsupportedOperation
        client
      end

      # Read a numeric identifier as an Integer
      #
      # @api private
      # @param value [String, Integer, nil] the identifier
      # @return [Integer, nil] the identifier or nil if it is missing
      def integer(value)
        Integer(value.to_s, 10) unless value.nil?
      end

      # Check whether a value identifies a resource rather than naming one
      #
      # An Integer is an identifier and a String is a name, such as a username, so that an
      # account whose username is all digits is looked up as the name it is.
      #
      # @api private
      # @param value [Resource, String, Integer] a resource, an identifier, or a username
      # @return [Boolean] true if the value is a resource or an Integer identifier
      def id?(value)
        value.is_a?(Resource) || value.instance_of?(Integer)
      end

      # Read a value of a response, which must be what the API documents it to be
      #
      # @api private
      # @param name [String] what the value is, such as the reader that reads it
      # @param value [Object] the value the response holds
      # @yieldparam value [Object] the value
      # @return [Object] what the block returns
      # @raise [InvalidAttribute] if the block raises ArgumentError for the value
      # @example Read the time a post was created
      #   X::Objects::Utils.read("X::Post#created_at", attrs["created_at"]) { |value| X::Objects::Utils.time(value) }
      def read(name, value)
        yield value
      rescue ArgumentError
        raise InvalidAttribute, "#{name} cannot be read from #{value.inspect}"
      end

      # Deconstruct a value into what its readers read, so it matches a hash pattern
      #
      # A pattern that asks for every key gets each reader by the name it is declared by, and one that names keys
      # gets those of them it names, by any name they are read by, as a resource matches a pattern.
      #
      # @api private
      # @param value [Object] the value, which answers each reader
      # @param keys [Array<Symbol>, nil] the keys the pattern asks for, or nil for every reader
      # @param names [Array<Symbol>] the readers
      # @param aliases [Array<Symbol>] the other names some of the readers are read by
      # @return [Hash{Symbol => Object}] what the readers the pattern asks for read
      # @example Deconstruct a trend
      #   X::Objects::Utils.deconstruct(trend, [:name], %i[name post_count], %i[tweet_count]) # => {name: "#ruby"}
      def deconstruct(value, keys, names, aliases = [])
        names = (names + aliases) & keys unless keys.nil?
        names.to_h { |name| [name, value.public_send(name)] }
      end

      # Parse an ISO 8601 timestamp
      #
      # A value that is not a String, such as a number, is not ISO 8601 either, and raises ArgumentError as one.
      #
      # @api private
      # @param value [String, nil] the timestamp
      # @return [Time, nil] the parsed time or nil if the timestamp is missing
      # @raise [ArgumentError] if the timestamp is not ISO 8601
      def time(value)
        Time.iso8601(value.to_s) unless value.nil?
      end
    end
    private_constant :Utils
  end
end
