require "monitor"
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
      def at(index)
        current = cached(index)
        prefetch(index + 1) if @cursor.prefetch? && current&.next_token
        current
      end

      private

      # Fetch a page by index, storing it in the cache
      # @api private
      # @param index [Integer] the zero-based page index
      # @return [Page, nil] the page or nil if the collection has fewer pages
      def cached(index)
        @monitor.synchronize { @pages[index] ||= fetch(index) }
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
        klass = @cursor.klass
        client = @cursor.client
        resources = klass.collection_from_response(body, client:, hydrated: true)
        id_only? ? resources.map { |resource| klass.from_id(resource, client:) } : resources
      end

      # Check whether the cursor requests nothing but identifiers
      # @api private
      # @return [Boolean] true if the fields parameter selects only the identifier
      def id_only? = @cursor.params[@cursor.klass.fields_key].eql?(@cursor.klass.id_key)

      # Build the query parameters for a page, including the previous page token
      # @api private
      # @param index [Integer] the zero-based page index
      # @return [Hash{String => Object}, nil] the parameters or nil if the previous page was the last
      def params_for(index)
        return @cursor.params if index.zero?

        token = cached(index - 1)&.next_token
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
