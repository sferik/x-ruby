# frozen_string_literal: true

require "json"
require_relative "errors"
require_relative "shape"

module X
  module Objects
    # One page of results from a paginated endpoint
    # @api public
    class ::X::Page
      include Enumerable

      # The number of the format of the state Marshal writes, which every release of 1.x writes
      #
      # A later release of 1.x adds to the state only what an earlier one ignores, parts after those it reads and keys of a
      # Hash it does not read, so that the state one release of 1.x writes is read by every other, earlier or later.
      MARSHAL_FORMAT = 1
      # The name YAML writes each part of the state under, in the order Marshal writes them
      YAML_KEYS = %w[format resources meta problems includes].freeze
      # The query parameters that name the resources of a lookup of several, which a problem of a response names when
      # it found none of them
      LIST_PARAMETERS = %w[ids media_keys usernames].freeze
      private_constant :MARSHAL_FORMAT, :YAML_KEYS, :LIST_PARAMETERS

      # The resources on this page
      # @api public
      # @return [Array<Resource>] the resources
      # @example Get the resources on a page
      #   page.items
      attr_reader :items

      # The problems the response of this page reported
      #
      # They are every problem of the response, where each resource of the page reports only those about it, or about
      # a resource it refers to.
      #
      # @api public
      # @return [Array<Problem>] the problems
      # @example Collect every problem a cursor's pages reported
      #   user.followers.each_page.flat_map(&:problems)
      attr_reader :problems

      # The pagination metadata returned with this page
      # @api public
      # @return [Hash{String => Object}] the metadata
      # @example Get the metadata
      #   page.meta # => {"result_count" => 100, "next_token" => "..."}
      attr_reader :meta

      # Initialize a new page
      #
      # @api public
      # @param items [Array<Resource>] the resources on the page
      # @param meta [Hash] the pagination metadata, empty by default, as for a page whose response holds none
      # @param problems [Array<Problem>] the problems the page's response reported
      # @return [Page] a new page, which holds frozen copies of the arrays it is given, leaving them as they are
      # @raise [ArgumentError] if the items are not an Array of resources, the metadata is not a Hash, or the problems
      #   are not an Array of problems
      # @example Create a page
      #   X::Page.new([user], meta: {"result_count" => 1})
      def initialize(items, meta: {}, problems: [])
        @items = resources!(items).dup.freeze
        @meta = Utils.deep_freeze(Hash.try_convert(meta) || raise(ArgumentError, "meta must be a Hash, not #{meta.inspect}"))
        @problems = problems!(problems).dup.freeze
        freeze
      end

      # Iterate over the resources on this page
      #
      # @api public
      # @yield [Resource] each resource
      # @return [Enumerator, Page] an enumerator without a block, otherwise self, as a cursor returns itself
      # @example Iterate over a page
      #   page.each { |user| puts user.username }
      def each(&block)
        return to_enum { size } unless block

        items.each(&block)
        self
      end

      # The resources on this page, frozen, as {#items} returns them
      #
      # @api public
      # @return [Array<Resource>] the resources
      # @example Get the resources on a page as an Array
      #   page.to_a
      def to_a = items

      alias_method :entries, :to_a

      # The number of resources on this page
      #
      # @api public
      # @return [Integer] the number of resources
      # @example Count the resources on a page
      #   page.size # => 100
      def size = items.size

      alias_method :length, :size

      # Check whether this page holds no resources
      #
      # @api public
      # @return [Boolean] true if the page holds none
      # @example Stop at an empty page
      #   break if page.empty?
      def empty? = items.empty?

      # The resource at an index, or the resources of a range, as Array#[] reads them
      #
      # @api public
      # @param args [Array<Integer, Range>] an index, a start and a length, or a range
      # @return [Resource, Array<Resource>, nil] the resource, or the resources, or nil for an index past the end
      # @example Get the first resource on a page
      #   page[0]
      def [](*args) = items[*args] # steep:ignore DifferentMethodParameterKind, UnresolvedOverloading

      # The last resource on this page, or the last few
      #
      # @api public
      # @param args [Array<Integer>] nothing for the last resource, or the number of resources to take from the end
      # @return [Resource, Array<Resource>, nil] the last resource, or the last resources, or nil for an empty page
      # @example Get the last resource on a page
      #   page.last
      def last(*args) = items.last(*args) # steep:ignore DifferentMethodParameterKind, UnresolvedOverloading

      # Check whether another page is the same page
      #
      # Its resources are compared as resources are, by class and identifier, so a page read again, or read back from
      # Marshal, equals the page it was read from.
      #
      # @api public
      # @param other [Object] the other page
      # @return [Boolean] true if the other page is a Page of the same resources, in the same order, with the same meta
      #   and problems
      # @example Check whether a page was read before
      #   seen.include?(page)
      def ==(other) = other.instance_of?(self.class) && state.eql?(other.__send__(:state))
      alias_method :eql?, :==

      # The hash of the page, which equal pages share
      #
      # @api public
      # @return [Integer] the hash
      # @example Count the distinct pages
      #   pages.uniq.size
      def hash = [self.class, state].hash

      # The token used to fetch the next page
      #
      # An empty token names no page, so a page whose meta holds one is the last, as a page whose meta holds none is,
      # rather than one whose next page is fetched with an empty token the API refuses.
      #
      # @api public
      # @return [String, nil] the token or nil if this is the last page
      # @example Get the next token
      #   page.next_token
      def next_token
        token = meta["next_token"]
        token unless token.eql?("")
      end

      # The number of results reported by the API
      #
      # @api public
      # @return [Integer, nil] the result count
      # @raise [InvalidAttribute] if the meta holds a result count that is not a number
      # @example Get the result count
      #   page.result_count
      def result_count
        Utils.read("#{self.class}#result_count", meta["result_count"]) { |value| Utils.integer(value) }
      end

      # This page, as a JSON encoder reads it, in the shape of the response it came from
      #
      # Its resources are the data, each given as its own as_json gives it, beside the meta of the page, which holds
      # the token of the next, and, when the response reported any, its problems as the errors, so that what this
      # returns is plain data, which ActiveSupport reads too, and which the from_response of the resource class builds
      # into a page again. The objects the response included are not among it, so a reference of a resource built
      # again from it is a stub.
      #
      # @api public
      # @return [Hash{String => Object}] the data, meta, and errors of the page, frozen
      # @example Serialize a page
      #   page.as_json # => {"data" => [{"id" => "7505382"}], "meta" => {"next_token" => "abc"}}
      # @example Build a page again from what it serialized to
      #   X::User.from_response(JSON.parse(page.to_json), client: client)
      def as_json(*)
        json = {"data" => map(&:as_json), "meta" => meta}
        json["errors"] = problems.map(&:to_h) unless problems.empty?
        json.freeze
      end

      # This page as a Hash in the shape of its response, or of a pair for each resource
      #
      # Without a block it is {#as_json}, as the to_h of a resource is its attributes, rather than the to_h of
      # Enumerable, which raises TypeError for resources that are not pairs. With a block it is the to_h of Enumerable,
      # which builds a Hash of the pair the block returns for each resource.
      #
      # @api public
      # @yieldparam resource [Resource] each resource
      # @yieldreturn [Array(Object, Object)] the key and value of the resource
      # @return [Hash] the data, meta, and errors of the page, frozen, or the pairs the block returns
      # @example Get the page in the shape of its response
      #   page.to_h # => {"data" => [{"id" => "7505382"}], "meta" => {"next_token" => "abc"}}
      # @example Index the users of a page by username
      #   page.to_h { |user| [user.username, user] }
      def to_h(&block) = block ? super() : as_json

      # This page as a JSON object in the shape of the response it came from
      #
      # @api public
      # @param state [JSON::State, nil] the state a JSON encoder passes, which the attributes are given
      # @return [String] the data, meta, and errors of the page as a JSON object
      # @example Serialize a page
      #   page.to_json # => "{\"data\":[{\"id\":\"7505382\"}],\"meta\":{}}"
      def to_json(state = nil) = as_json.to_json(state)

      # The meta of a response, which holds the token of its next page
      #
      # A cursor and the from_response of a resource class read the meta of the pages they build with it, so that a
      # meta that is not an object raises alike, rather than end the paging of one of them without a word.
      #
      # @api private
      # @param body [Hash, nil] the parsed response body
      # @return [Hash{String => Object}] the meta, empty if the response holds none
      # @raise [InvalidAttribute] if the response holds a meta that is not an object
      # @example Read the meta of a response
      #   X::Page.__send__(:meta_of, {"meta" => {"next_token" => "abc"}}) # => {"next_token" => "abc"}
      def self.meta_of(body) = Shape.read_object("#{self}#meta", body.to_h["meta"]) || {}
      private_class_method :meta_of

      # Whether a response holds a list
      #
      # The from_response of a resource class builds a page of a response that holds one.
      #
      # A response holds one when its data is an array, and when it holds no data and either a meta, which must then
      # be an object, or a problem that names a parameter of a lookup of several, as one that found none of them does.
      #
      # @api private
      # @param body [Hash] the parsed response body
      # @return [Boolean] true if the response holds a list
      # @example Ask whether an empty list is one
      #   X::Page.__send__(:list?, {"meta" => {"result_count" => 0}}) # => true
      def self.list?(body)
        data = body["data"]
        data.is_a?(Array) || (data.nil? && (body.key?("meta") || Problem.all_from(body).any? { |problem| LIST_PARAMETERS.include?(problem.parameter) }))
      end
      private_class_method :list?

      # The state Marshal writes
      #
      # What is written is plain data, led by the number of its format, so that a page written by one release of 1.x is
      # read by a later one: each resource, as its class, its attributes, and whether it is hydrated, without its client;
      # the included objects the resources refer to, once for the resources that came from one response, as a resource
      # writes those it refers to, so that the resources that resolved a reference to the same object still do; its
      # metadata; and its problems.
      #
      # @api public
      # @return [Array] the number of the format, then the state of the page
      # @example Cache a page
      #   Rails.cache.write("followers", user.followers.page(0))
      def marshal_dump
        responses = group_by { |item| response_of(item) }
        [MARSHAL_FORMAT, resource_states(responses.keys), meta, problems, responses.map { |includes, members| includes.state_of(members) }]
      end

      # Restore a page Marshal read, frozen as the page that was written was
      #
      # The resources that came from one response are built over one identity map again, so a reference they share
      # resolves to the same object, as it did before the page was written. Each is hydrated if it was, and the query of
      # its request asks for every field this release requests, as a resource Marshal reads is.
      #
      # @api public
      # @param state [Array] the state Marshal wrote
      # @return [void]
      # @raise [UnsupportedMarshalFormat] if the state is of a format this release does not read
      # @example Read a cached page
      #   Marshal.load(Marshal.dump(page)).next_token
      def marshal_load(state)
        format, resources, meta, problems, responses = state
        raise UnsupportedMarshalFormat, "#{self.class} reads format #{MARSHAL_FORMAT} of Marshal, not #{format.inspect}" unless MARSHAL_FORMAT.eql?(format)

        responses = responses.map { |data, about, query| Includes.new(data, problems: about, query:) }
        initialize(resources.map { |klass, attrs, hydrated, response| read(klass, attrs, hydrated, responses.fetch(response)) }, meta:, problems:)
      end

      # Write the state Marshal writes as YAML, without the clients of the resources
      #
      # YAML reads no marshal_dump, and would write every instance variable of each resource, its client and the
      # credentials it holds among them, so a page says how it is written: each part of the state Marshal writes, under
      # its name.
      #
      # @api public
      # @param coder [Psych::Coder] the coder YAML writes the page with
      # @return [void]
      # @example Write a page as YAML
      #   YAML.dump(user.followers.page(0))
      def encode_with(coder) = YAML_KEYS.zip(marshal_dump) { |key, value| coder[key] = value }

      # Restore a page YAML read, frozen, as Marshal restores one
      #
      # @api public
      # @param coder [Psych::Coder] the coder YAML read the page with
      # @return [void]
      # @raise [UnsupportedMarshalFormat] if the state is of a format this release does not read
      # @example Read a page written as YAML
      #   YAML.unsafe_load(YAML.dump(page)).next_token
      def init_with(coder) = marshal_load(coder.map.values_at(*YAML_KEYS))

      private

      # What a page is compared by: its resources, meta, and problems
      # @api private
      # @return [Array(Array<Resource>, Hash, Array<Problem>)] the resources, meta, and problems
      def state = [items, meta, problems]

      # The identity map of the response a resource came from
      # @api private
      # @param resource [Resource] the resource
      # @return [Objects::Includes] the identity map
      def response_of(resource) = resource.__send__(:includes)

      # Build a resource Marshal read of the page, over the identity map of its response
      # @api private
      # @param klass [Class] the resource class
      # @param attrs [Hash] the attributes
      # @param hydrated [Boolean] whether the resource was hydrated as it was written
      # @param includes [Objects::Includes] the identity map of its response
      # @return [Resource] the resource
      def read(klass, attrs, hydrated, includes) = klass.__send__(:build, attrs, includes:, hydrated: includes.hydrated_as_read?(klass, hydrated))

      # What Marshal writes of each resource of the page
      #
      # It is the class of the resource, its attributes, whether it is hydrated, and which response it came from.
      #
      # @api private
      # @param responses [Array<Objects::Includes>] the identity map of each response the resources came from
      # @return [Array<Array(Class, Hash, Boolean, Integer)>] the state of each resource
      def resource_states(responses)
        indexes = responses.each_with_index.to_h
        map { |item| [item.class, item.attrs, item.hydrated?, indexes.fetch(response_of(item))] } #: Array[[singleton(Resource), Objects::attrs, bool, Integer]]
      end

      # The resources a page is given, which must be an Array of them
      #
      # Items that are not, such as nil, would otherwise be taken, and raise NoMethodError when the page is read.
      #
      # @api private
      # @param items [Array<Resource>] the resources
      # @return [Array<Resource>] the resources
      # @raise [ArgumentError] if the items are not an Array of resources
      def resources!(items)
        resources = Array.try_convert(items)
        return resources if resources&.all?(Resource)

        raise ArgumentError, "items must be an Array of resources, not #{items.inspect}"
      end

      # The problems a page is given, which must be an Array of problems
      # @api private
      # @param problems [Object] the problems
      # @return [Array<Problem>] the problems
      # @raise [ArgumentError] if the problems are not an Array of problems
      def problems!(problems)
        array = Array.try_convert(problems)
        return array if array&.all?(Problem)

        raise ArgumentError, "problems must be an Array of problems, not #{problems.inspect}"
      end
    end
  end
end
