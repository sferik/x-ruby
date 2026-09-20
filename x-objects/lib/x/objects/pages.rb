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
      # @param limit [Integer, nil] the number of resources wanted, which sizes the pages and ends the cursor
      # @return [Pages] the pages
      def initialize(cursor, limit)
        @cursor = cursor
        @limit = limit
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

      # Check whether the pages already fetched answer a request for so many resources
      #
      # A cursor that has been read holds its pages, so first, take, and the predicates built on them read what is
      # there rather than pay for another request.
      #
      # @api private
      # @param count [Integer] the number of resources wanted
      # @return [Boolean] true if the pages fetched hold that many, or the last of them ends the collection
      def satisfy?(count)
        fetched = @monitor.synchronize { @pages.take_while { |page| !page.nil? } }
        last = fetched.fetch(-1, nil)
        return false if last.nil?

        fetched.sum { |page| page.to_a.size } >= count || last.next_token.nil?
      end

      private

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
      # @return [Page, nil] the page or nil if the previous page was the last
      def fetch(index)
        params = params_for(index)
        return if params.nil?

        body = @cursor.client.get(Utils.path(@cursor.path, params), **Utils::JSON_CLASSES)
        Page.new(resources_from(body), body.to_h["meta"].to_h, problems: Problem.all_from(body))
      end

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
        next_params(token) unless token.nil?
      end

      # The query parameters of a page, asking for what the pages before it left
      # @api private
      # @param token [String] the token of the next page
      # @return [Hash{String => Object}, nil] the parameters, or nil once the limit is fetched
      def next_params(token)
        params = @cursor.params
        paged = params.merge(@cursor.token_param => token)
        limit = @limit
        return paged if limit.nil?

        remaining = limit - @pages.sum { |page| page.to_a.size }
        paged.merge("max_results" => remaining.clamp(@cursor.min_results, Integer(params.fetch("max_results")))) if remaining.positive?
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
