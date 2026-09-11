require "forwardable"

module X
  # One page of results from a paginated endpoint
  # @api public
  class Page
    extend Forwardable
    include Enumerable

    # The resources on this page
    # @api public
    # @return [Array<Objects::Resource>] the resources
    # @example Get the resources on a page
    #   page.items
    attr_reader :items

    # The pagination metadata returned with this page
    # @api public
    # @return [Hash{String => Object}] the metadata
    # @example Get the metadata
    #   page.meta # => {"result_count" => 100, "next_token" => "..."}
    attr_reader :meta

    # Initialize a new page
    #
    # @api public
    # @param items [Array<Objects::Resource>] the resources on the page
    # @param meta [Hash] the pagination metadata
    # @return [Page] a new page
    # @example Create a page
    #   X::Page.new(items: [user], meta: {"result_count" => 1})
    def initialize(items:, meta:)
      @items = items.freeze
      @meta = Objects::Utils.deep_freeze(meta)
      freeze
    end

    # @!method each
    #   Iterate over the resources on this page
    #   @api public
    #   @yield [Objects::Resource] each resource
    #   @return [Enumerator, Array<Objects::Resource>] an enumerator without a block, otherwise the resources
    #   @example Iterate over a page
    #     page.each { |user| puts user.username }
    def_delegator :items, :each

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
  end
end
