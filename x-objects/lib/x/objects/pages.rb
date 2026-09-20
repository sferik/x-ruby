# frozen_string_literal: true

require "monitor"
require_relative "batch"
require_relative "finders"
require_relative "page"
require_relative "problem"
require_relative "utils"

module X
  module Objects
    # The pages of a cursor, fetched when they are asked for and kept
    # @api private
    class Pages
      # Initialize the pages of a cursor
      #
      # @api private
      # @param cursor [Cursor] the cursor whose pages these are
      # @return [Pages] the pages
      def initialize(cursor)
        @cursor = cursor
        @monitor = Monitor.new
        @pages = []
        freeze
      end

      # The page at an index, fetching the next in the background when prefetching
      #
      # @api private
      # @param index [Integer] the zero-based page index
      # @return [Page, nil] the page or nil if the collection has fewer pages
      # @raise [ArgumentError] if the index is negative, since pages are read forward from the first
      def at(index)
        raise ArgumentError, "#{index} is not a page index: pages are numbered from zero" if index.negative?

        current = cached(index)
        prefetch(index + 1) if @cursor.prefetch? && current&.next_token
        current
      end

      # The first resources, reading pages no larger than needed and keeping them
      #
      # The pages already fetched are read first, so a cursor that holds what is asked for pays for no request, and
      # each page fetched asks for no more than what is asked for that the pages before it left, raised to the
      # smallest page the endpoint accepts. The pages it fetches are kept, as every page is, so an iteration after
      # it requests only what it left.
      #
      # @api private
      # @param count [Integer] the number of resources wanted
      # @return [Array<Resource>] the first resources, fewer if the collection holds fewer
      # @raise [ArgumentError] if the count is negative, which Array#first raises for
      def read(count)
        @monitor.synchronize do
          resources = fetched.flat_map(&:to_a)
          while resources.size < count && (page = next_page(count - resources.size))
            resources.concat(page.to_a)
          end
          resources.first(count)
        end
      end

      private

      # The pages fetched so far
      #
      # A nil marks the end of the collection, and only ever follows every page, so what is not nil is every page.
      #
      # @api private
      # @return [Array<Page>] the pages
      def fetched = @pages.compact

      # Fetch and keep the page after the pages fetched so far, sized for what is wanted
      # @api private
      # @param wanted [Integer] the number of resources wanted from the page
      # @return [Page, nil] the page, or nil if the collection has no more
      def next_page(wanted)
        index = fetched.size
        @pages[index] ||= fetch(index, wanted)
      end

      # Fetch the pages up to an index, in order, storing each in the cache
      #
      # The token of one page asks for the next, so the pages before an index are read first, one after another
      # rather than one within another, since a collection of many pages would otherwise nest as deep as it is long.
      #
      # @api private
      # @param index [Integer] the zero-based page index
      # @return [Page, nil] the page or nil if the collection has fewer pages
      def cached(index)
        @monitor.synchronize do
          page = nil #: Page?
          (0..index).each do |current|
            page = @pages[current] ||= fetch(current)
            break if page.nil?
          end
          page
        end
      end

      # Fetch a page from the API
      # @api private
      # @param index [Integer] the zero-based page index
      # @param wanted [Integer, nil] the number of resources wanted from the page, or nil for the page size
      # @return [Page, nil] the page or nil if the previous page was the last
      def fetch(index, wanted = nil)
        params = params_for(index)
        return if params.nil?

        params = sized(params, wanted) unless wanted.nil?
        body = requester.get(Utils.path(@cursor.path, params), **Utils::JSON_CLASSES)
        Page.new(resources_from(body), body.to_h["meta"].to_h, problems: Problem.all_from(body))
      end

      # The client that fetches the pages, app-only for an endpoint that takes it
      # @api private
      # @return [Object] the client
      def requester = @cursor.app_only? ? Utils.app_client(@cursor.client) : @cursor.client

      # Build the resources of a page, as stubs for a cursor of identifiers
      # @api private
      # @param body [Hash, nil] the response body
      # @return [Array<Resource>] the resources
      def resources_from(body)
        klass = @cursor.resource_class
        resources = klass.collection_from_response(body, client: @cursor.client, hydrated: klass.fully_requested_by?(@cursor.params))
        id_only? ? stubs_from(resources) : resources
      end

      # The stubs of a page, which hydrate together, a lookup's worth at a time
      #
      # Hydrating one stub looks up the stubs of its batch in one request, rather than every stub of a page of up
      # to a thousand, since the API bills each resource a lookup returns. A resource without a batch lookup, such
      # as a list, hydrates each stub on its own.
      #
      # @api private
      # @param resources [Array<Resource>] the resources of the page
      # @return [Array<Resource>] the stubs
      def stubs_from(resources)
        klass = @cursor.resource_class
        client = @cursor.client
        resources.each_slice(Finders::MAX_BATCH_SIZE).flat_map do |slice|
          batch = (Batch.new(klass, slice, client:) if klass.batchable?)
          slice.map { |resource| klass.from_id(resource, client:, batch:) }
        end
      end

      # Check whether the cursor requests nothing but identifiers
      # @api private
      # @return [Boolean] true if the fields parameter selects only the identifier
      def id_only? = @cursor.params[@cursor.resource_class.fields_key].eql?(@cursor.resource_class.id_key)

      # Build the query parameters for a page, including the previous page token
      #
      # The page before this one is already fetched, since the pages are read in order.
      #
      # @api private
      # @param index [Integer] the zero-based page index
      # @return [Hash{String => Object}, nil] the parameters or nil if the previous page was the last
      def params_for(index)
        return @cursor.params if index.zero?

        previous = @pages.fetch(index - 1) #: Page
        token = previous.next_token
        @cursor.params.merge(@cursor.token_param => token) unless token.nil?
      end

      # The query parameters of a page, asking for no more than the resources wanted
      #
      # A cursor over an endpoint without a page size asks for the page as it is.
      #
      # @api private
      # @param params [Hash{String => Object}] the query parameters of the page
      # @param wanted [Integer] the number of resources wanted
      # @return [Hash{String => Object}] the parameters, with the page size wanted, within the endpoint's limits
      def sized(params, wanted)
        maximum = params["max_results"]
        return params if maximum.nil?

        params.merge("max_results" => wanted.clamp(@cursor.min_results, Integer(maximum)))
      end

      # Fetch a page in a background thread; errors resurface when the page is requested
      # @api private
      # @param index [Integer] the zero-based page index
      # @return [Thread] the background thread
      def prefetch(index)
        Thread.new do
          cached(index)
        rescue
          nil
        end
      end
    end
  end
end
