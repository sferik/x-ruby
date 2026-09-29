# frozen_string_literal: true

require_relative "includes"

module X
  module Objects
    # The state of a resource Marshal writes and reads
    #
    # Internal to x-objects: the methods it gives a resource, marshal_dump and marshal_load, are public API, but the
    # module is only how they are given, and which classes include it can change within 1.x.
    #
    # @api private
    module Marshalling
      # The number of the format of the state Marshal writes, which a release that changes the format raises
      FORMAT = 1

      # The state Marshal writes, which leaves out the client
      #
      # The client is left out, since it holds credentials and a connection. What is written is plain data, led by
      # the number of its format, so that a resource written by one release of 1.x is read by a later one: its
      # attributes, whether it is hydrated, and the includes, problems, and query of the response it came from, so
      # that the references it resolves, and the problems it reports, are what they were.
      #
      # @api public
      # @return [Array] the number of the format, then the state of the resource
      # @example Cache a user
      #   Rails.cache.write("user", user)
      def marshal_dump
        data, problems, query = includes.state # steep:ignore NoMethod
        [FORMAT, attrs, hydrated?, data, problems, query]
      end

      # Restore a resource Marshal read, which has no client and so makes no request
      #
      # What Marshal reads is a client-less resource that answers its readers, resolves the references its response
      # included, and reports its problems, as the resource that was written did, and raises from a hydrate, refresh,
      # or collection that would make a request.
      #
      # @api public
      # @param state [Array] the state Marshal wrote
      # @return [void]
      # @raise [ArgumentError] if the state is of a format this release does not read
      # @example Read a cached user
      #   Marshal.load(Marshal.dump(user)).username # => "sferik"
      def marshal_load(state)
        format, attrs, hydrated, data, problems, query = state
        raise ArgumentError, "#{self.class} reads format #{FORMAT} of Marshal, not #{format.inspect}" unless FORMAT.eql?(format)

        setup(attrs, client: nil, hydrated:, includes: Includes.new(data, problems: problems.map { |problem| Problem.new(problem) }, query:)) # steep:ignore NoMethod
      end
    end
  end
end
