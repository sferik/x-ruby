# frozen_string_literal: true

require "json"
require_relative "errors"

module X
  # One page of results from a paginated endpoint
  # @api public
  class Page
    include Enumerable

    # The number of the format of the state Marshal writes, which a release that changes the format raises
    MARSHAL_FORMAT = 1
    private_constant :MARSHAL_FORMAT

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
    # @param meta [Hash] the pagination metadata
    # @param problems [Array<Problem>] the problems the page's response reported
    # @return [Page] a new page
    # @raise [ArgumentError] if the items are not an Array of resources, or the metadata is not a Hash
    # @example Create a page
    #   X::Page.new([user], {"result_count" => 1})
    def initialize(items, meta, problems: [])
      @items = resources!(items).freeze
      @meta = Objects::Utils.deep_freeze(Hash.try_convert(meta) || raise(ArgumentError, "meta must be a Hash, not #{meta.inspect}"))
      @problems = problems.freeze
      freeze
    end

    # Iterate over the resources on this page
    #
    # @api public
    # @yield [Resource] each resource
    # @return [Enumerator, Array<Resource>] an enumerator without a block, otherwise the resources
    # @example Iterate over a page
    #   page.each { |user| puts user.username }
    def each(&) = items.each(&) # steep:ignore BlockTypeMismatch

    # The token used to fetch the next page
    #
    # @api public
    # @return [String, nil] the token or nil if this is the last page
    # @example Get the next token
    #   page.next_token
    def next_token
      meta["next_token"]
    end

    # The number of results reported by the API
    #
    # @api public
    # @return [Integer, nil] the result count
    # @example Get the result count
    #   page.result_count
    def result_count
      meta["result_count"]
    end

    # The attributes of the resources of this page, as a JSON encoder reads them
    #
    # Each resource is given as its own as_json gives it, so what this returns is plain data, as the as_json of a
    # resource is, which ActiveSupport reads too.
    #
    # @api public
    # @return [Array<Hash{String => Object}>] the attributes of each resource, frozen
    # @example Serialize a page
    #   page.as_json # => [{"id" => "7505382"}]
    def as_json(*) = map(&:as_json).freeze

    # The resources of this page as a JSON array of their attributes
    #
    # @api public
    # @param state [JSON::State, nil] the state a JSON encoder passes, which the attributes are given
    # @return [String] the resources as a JSON array
    # @example Serialize a page
    #   page.to_json # => "[{\"id\":\"7505382\"}]"
    def to_json(state = nil) = as_json.to_json(state)

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
    # resolves to the same object, as it did before the page was written.
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

      responses = responses.map { |data, about, query| Objects::Includes.new(data, problems: about, query:) }
      initialize(resources.map { |klass, attrs, hydrated, response| klass.__send__(:build, attrs, includes: responses.fetch(response), hydrated:) }, meta, problems:)
    end

    private

    # The identity map of the response a resource came from
    # @api private
    # @param resource [Resource] the resource
    # @return [Objects::Includes] the identity map
    def response_of(resource) = resource.__send__(:includes)

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
  end
end
