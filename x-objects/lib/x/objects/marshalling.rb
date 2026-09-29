# frozen_string_literal: true

require_relative "errors"
require_relative "includes"

module X
  module Objects
    # The state of a resource Marshal and YAML write and read
    #
    # Internal to x-objects: the methods it gives a resource, marshal_dump, marshal_load, encode_with, and init_with,
    # are public API, but the module is only how they are given, and which classes include it can change within 1.x.
    #
    # @api private
    module Marshalling
      # The number of the format of the state Marshal writes, which a release that changes the format raises
      MARSHAL_FORMAT = 1
      # The name YAML writes each part of the state under, in the order Marshal writes them
      YAML_KEYS = %w[format attrs hydrated includes problems query].freeze
      private_constant :MARSHAL_FORMAT, :YAML_KEYS

      # The state Marshal writes, which leaves out the client
      #
      # The client is left out, since it holds credentials and a connection. What is written is plain data, led by
      # the number of its format, so that a resource written by one release of 1.x is read by a later one: its
      # attributes, whether it is hydrated, and, of the response it came from, the included objects it refers to, and
      # those they refer to in turn, the problems about any of them, and the query, so that the references it
      # resolves, and the problems it and they report, are what they were, while the rest of the response is left
      # out, however many other resources it held.
      #
      # @api public
      # @return [Array] the number of the format, then the state of the resource
      # @example Cache a user
      #   Rails.cache.write("user", user)
      def marshal_dump
        data, problems, query = includes.state_of([self]) # steep:ignore NoMethod
        [MARSHAL_FORMAT, attrs, hydrated?, data, problems, query]
      end

      # Restore a resource Marshal read, which has no client and so makes no request
      #
      # What Marshal reads is a client-less resource that answers its readers, resolves the references its response
      # included, and reports its problems, as the resource that was written did, and raises from a hydrate, refresh,
      # or collection that would make a request. It is hydrated if it was, and the query of its request asks for every
      # field this release requests, so that one written before a minor release added to the fields is not.
      #
      # @api public
      # @param state [Array] the state Marshal wrote
      # @return [void]
      # @raise [UnsupportedMarshalFormat] if the state is of a format this release does not read
      # @example Read a cached user
      #   Marshal.load(Marshal.dump(user)).username # => "sferik"
      def marshal_load(state)
        format, attrs, hydrated, data, problems, query = state
        raise UnsupportedMarshalFormat, "#{self.class} reads format #{MARSHAL_FORMAT} of Marshal, not #{format.inspect}" unless MARSHAL_FORMAT.eql?(format)

        includes = Includes.new(data, problems:, query:)
        setup(attrs, client: nil, hydrated: includes.hydrated_as_read?(self.class, hydrated), includes:) # steep:ignore NoMethod
      end

      # Write the state Marshal writes as YAML, which leaves out the client
      #
      # YAML reads no marshal_dump, and would write every instance variable, the client and its credentials among
      # them, so a resource says how it is written: each part of the state Marshal writes, under its name.
      #
      # @api public
      # @param coder [Psych::Coder] the coder YAML writes the resource with
      # @return [void]
      # @example Write a user as YAML, as a queue writes the arguments of a job
      #   YAML.dump(user)
      def encode_with(coder) = YAML_KEYS.zip(marshal_dump) { |key, value| coder[key] = value }

      # Restore a resource YAML read, as Marshal restores one
      #
      # It has no client, and so makes no request.
      #
      #
      # @api public
      # @param coder [Psych::Coder] the coder YAML read the resource with
      # @return [void]
      # @raise [UnsupportedMarshalFormat] if the state is of a format this release does not read
      # @example Read a user written as YAML
      #   YAML.unsafe_load(YAML.dump(user)).username # => "sferik"
      def init_with(coder) = marshal_load(coder.map.values_at(*YAML_KEYS))
    end
  end
end
