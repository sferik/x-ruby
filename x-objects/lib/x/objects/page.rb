# frozen_string_literal: true

require "json"

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
    # @example Create a page
    #   X::Page.new([user], {"result_count" => 1})
    def initialize(items, meta, problems: [])
      @items = items.freeze
      @meta = Objects::Utils.deep_freeze(meta)
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
    # read by a later one: its resources, which Marshal writes as a resource writes itself, without its client, its
    # metadata, and the attributes of its problems.
    #
    # @api public
    # @return [Array] the number of the format, then the state of the page
    # @example Cache a page
    #   Rails.cache.write("followers", user.followers.page(0))
    def marshal_dump = [MARSHAL_FORMAT, items, meta, problems.map(&:attrs)]

    # Restore a page Marshal read, frozen as the page that was written was
    #
    # @api public
    # @param state [Array] the state Marshal wrote
    # @return [void]
    # @raise [ArgumentError] if the state is of a format this release does not read
    # @example Read a cached page
    #   Marshal.load(Marshal.dump(page)).next_token
    def marshal_load(state)
      format, items, meta, problems = state
      raise ArgumentError, "#{self.class} reads format #{MARSHAL_FORMAT} of Marshal, not #{format.inspect}" unless MARSHAL_FORMAT.eql?(format)

      initialize(items, meta, problems: problems.map { |problem| Problem.new(problem) })
    end
  end
end
