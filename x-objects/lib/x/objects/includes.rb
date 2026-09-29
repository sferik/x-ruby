# frozen_string_literal: true

require "monitor"
require_relative "utils"

module X
  module Objects
    # The context of one API response: its identity map of expanded objects and stubs, and the problems it reported
    # @api private
    class Includes
      # Initialize a new identity map
      #
      # @api private
      # @param data [Hash, nil] the includes hash from an API response
      # @param problems [Array<Problem>] the problems the response reported
      # @param query [Hash{String => Object}, nil] the query parameters of the request, merged over the defaults, or
      #   nil if they are not known
      # @return [Includes] a new identity map
      def initialize(data = nil, problems: [], query: nil)
        @data = Utils.deep_freeze(data.to_h)
        @problems = problems.freeze
        @query = query.dup
        @monitor = Monitor.new
        @index = {}
        @resources = {}
        freeze
      end

      # The problems the response reported, such as missing expanded resources
      # @api private
      # @return [Array<Problem>] the problems
      attr_reader :problems

      # Resolve a reference to the included resource or a stub holding its identifier
      #
      # Every reference to the same resource within one response resolves to the same object,
      # so hydrating it once hydrates it everywhere it is referenced.
      #
      # An included resource is hydrated when the request asked for every field of its class, and its class expands
      # nothing of its own, as a poll, a place, and media expand nothing, since the API applies the expansions of a
      # request to its data alone: a post or a user included in a response lacks the resources it would expand, which
      # hydrate looks up. A stub, of a resource the response did not include, is never hydrated.
      #
      # @api private
      # @param klass [Class] the resource class
      # @param id [String] the identifier
      # @param client [Object, nil] the client used to fetch the response
      # @return [Resource] the resource
      def resolve(klass, id, client:)
        @monitor.synchronize do
          @resources[[klass, id]] ||= build(klass, id, client)
        end
      end

      private

      # Build the included resource an identifier names, or a stub of it
      # @api private
      # @param klass [Class] the resource class
      # @param id [String] the identifier
      # @param client [Object, nil] the client used to fetch the response
      # @return [Resource] the resource
      def build(klass, id, client)
        attrs = index(klass)[id]
        return klass.__send__(:build, {klass.__send__(:id_key) => id}, client:, includes: self) if attrs.nil?

        klass.__send__(:build, attrs, client:, includes: self, hydrated: fully_requested?(klass))
      end

      # Check whether the request asked for every field of a class that expands nothing
      # @api private
      # @param klass [Class] the resource class
      # @return [Boolean] true if a resource of the class that the response included holds every field
      def fully_requested?(klass)
        query = @query
        return false if query.nil? || klass.default_params.key?("expansions")

        klass.__send__(:fully_requested_by?, query)
      end

      # Build or fetch the identifier index for one type of expanded object
      #
      # @api private
      # @param klass [Class] the resource class
      # @return [Hash{String => Hash}] the expanded objects keyed by identifier
      def index(klass)
        key = klass.__send__(:includes_key)
        entries = @data.fetch(key, []) #: Array[Hash[String, untyped]]
        @index[key] ||= entries.group_by { |attrs| attrs[klass.__send__(:id_key)] }.transform_values(&:first)
      end
    end
  end
end
