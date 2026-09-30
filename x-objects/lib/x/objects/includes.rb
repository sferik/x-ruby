# frozen_string_literal: true

require "monitor"
require_relative "utils"

module X
  module Objects
    # The context of one API response: its identity map of expanded objects and stubs, and the problems it reported
    # @api private
    class Includes
      # The keys the API gave the includes of a class before it named tweets posts, which it still gives them where it
      # has not renamed them, such as in a stream
      TWEET_KEYS = {"posts" => "tweets"}.freeze
      private_constant :TWEET_KEYS

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

      # What some resources built over the identity map refer to of it, as plain data
      #
      # A resource that Marshal writes holds it, and a page holds it once for the resources that share it. It is the
      # included objects the resources refer to, and the ones those refer to in turn, so that every reference that
      # resolves to an included object still does, with none of the rest of the response; the problems about any of
      # them, or about none; and the query, which tells whether an included object is hydrated. The problems are
      # written as themselves, which Marshal writes as their attributes.
      #
      # @api private
      # @param resources [Array<Resource>] the resources, each built over this identity map
      # @return [Array(Hash, Array<Problem>, Hash, nil)] the included objects, the problems, and the query
      def state_of(resources)
        kept = {} #: Hash[String, Array[attrs]]
        ids = resources.map(&:id)
        pending = resources.map { |resource| [resource.class, resource.attrs] } #: Array[[singleton(Resource), attrs]]
        # Each object kept joins the objects whose references are read, which each reaches once it comes to them
        pending.each do |klass, attrs|
          referenced = referenced_by(klass, attrs)
          ids.concat(referenced)
          pending.concat(keep(kept, referenced))
        end
        [kept, problems_about(ids), @query]
      end

      # Check whether a resource of the response is hydrated as it is read back
      #
      # A resource written with the query of its request is hydrated only if that query asks for every field and
      # expansion this release requests of its class, since a minor release may add to them, so that a resource an
      # earlier release wrote as hydrated is not, once it lacks what was added, and hydrate fetches it. One written
      # without a query, as one a caller built from a response is, is hydrated as it was written.
      #
      # @api private
      # @param klass [Class] the resource class
      # @param hydrated [Boolean] whether the resource was hydrated as it was written
      # @return [Boolean] true if the resource holds every field this release requests
      def hydrated_as_read?(klass, hydrated)
        query = @query
        hydrated && (query.nil? || klass.__send__(:fully_requested_by?, query))
      end

      # The problems the response reported about any of some identifiers
      #
      # A problem that names no resource is about any of them, too. A problem names the resource it is about by its resource_id, or by its value, and one that names neither
      # could be about any resource of the response.
      #
      # @api private
      # @param ids [Array<Object>] the identifiers of a resource and of the resources it refers to
      # @return [Array<Problem>] the problems, frozen
      def problems_about(ids)
        ids = ids.map(&:to_s)
        problems.select { |problem| about?(problem, ids) }.freeze
      end

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

      # Check whether a problem names one of some identifiers, or names none
      # @api private
      # @param problem [Problem] the problem
      # @param ids [Array<String>] the identifiers
      # @return [Boolean] true if the problem names one of the identifiers, or names no resource
      def about?(problem, ids)
        named = [problem.resource_id, problem.value].compact
        named.empty? || named.any? { |value| ids.include?(value.to_s) }
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

      # Keep the included objects some identifiers name that are not kept yet
      #
      # An object is kept under the key the response included it by, in the order the response included it, so that
      # what is kept resolves as the response did.
      #
      # @api private
      # @param kept [Hash{String => Array<Hash>}] the included objects kept so far, which this adds to
      # @param ids [Array<Object>] the identifiers, as the objects that refer to them hold them
      # @return [Array(Class, Hash)] the class and attributes of each object this kept, whose references are kept next
      def keep(kept, ids)
        collections.flat_map do |klass, key|
          found = named(klass, key, ids) - kept[key].to_a
          kept[key] = @data.fetch(key) & (kept[key].to_a + found) unless found.empty?
          found.map { |attrs| [klass, attrs] }
        end
      end

      # The included objects of a resource class that some identifiers name
      # @api private
      # @param klass [Class] the resource class
      # @param key [String] the key the response included the objects of the class under
      # @param ids [Array<Object>] the identifiers
      # @return [Array<Hash>] the objects, in the order the response included them
      def named(klass, key, ids) = @data.fetch(key).select { |attrs| ids.include?(attrs[klass.__send__(:id_key)]) }

      # The identifiers of what an object refers to, as the object holds them
      #
      # A reference resolves an identifier as the object holds it, so it is kept as that too.
      #
      # @api private
      # @param klass [Class] the resource class of the object
      # @param attrs [Hash{String => Object}] the attributes of the object
      # @return [Array<Object>] the identifiers
      def referenced_by(klass, attrs) = klass.__send__(:referenced_ids, attrs).compact

      # The key the response included each resource class under, of those it included
      # @api private
      # @return [Array<Array(Class, String)>] each class, and the key the response included it under
      def collections
        classes = Resource.subclasses #: Array[singleton(Resource)]
        classes.filter_map do |klass|
          name = klass.__send__(:includes_key)
          key = [name, TWEET_KEYS[name]].find { |candidate| @data.key?(candidate) } #: String?
          [klass, key] unless key.nil?
        end
      end

      # The included objects of one resource class, under the key the API gave them
      # @api private
      # @param klass [Class] the resource class
      # @return [Array<Hash>] the included objects, empty if the response included none
      def entries_of(klass)
        key = klass.__send__(:includes_key)
        @data.fetch(key) { @data.fetch(TWEET_KEYS[key], []) }
      end

      # Build or fetch the identifier index for one type of expanded object
      #
      # @api private
      # @param klass [Class] the resource class
      # @return [Hash{String => Hash}] the expanded objects keyed by identifier
      def index(klass)
        @index[klass.__send__(:includes_key)] ||= entries_of(klass).group_by { |attrs| attrs[klass.__send__(:id_key)] }.transform_values(&:first)
      end
    end
    private_constant :Includes
  end
end
