# frozen_string_literal: true

require "monitor"
require_relative "batch"
require_relative "batch_finders"
require_relative "errors"
require_relative "page"
require "x/core/problem"
require_relative "utils"

module X
  module Objects
    # The pages of a cursor, fetched when they are asked for and kept
    # @api private
    class Pages
      # The message of the error raised for a page whose next token fetched an earlier page
      REPEATED_TOKEN = "Page %<index>d of %<path>s names the next_token %<token>p, which fetched an earlier page"
      private_constant :REPEATED_TOKEN

      # Initialize the pages of a cursor
      #
      # @api private
      # @param cursor [Cursor] the cursor whose pages these are
      # @return [Pages] the pages
      def initialize(cursor)
        @cursor = cursor
        @monitor = Monitor.new
        @pages = []
        @prefetching = Set.new
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
          resources.first(count).freeze
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
      # @raise [InvalidAttribute] if the previous page names the token of a page before it as the next
      def fetch(index, wanted = nil)
        params = params_for(index)
        return if params.nil?

        params = sized(params, wanted) unless wanted.nil?
        body = requester.get(Utils.path(@cursor.path, params), **Utils::JSON_CLASSES)
        Page.new(resources_from(body), body.to_h["meta"].to_h, problems: Problem.all_from(body))
      end

      # The client that fetches the pages, as the app for a space endpoint
      # @api private
      # @return [Object] the client
      def requester = @cursor.app_only? ? Utils.space_client(@cursor.client) : @cursor.client

      # Build the resources of a page, as stubs for a cursor of identifiers
      # @api private
      # @param body [Hash, nil] the response body
      # @return [Array<Resource>] the resources
      def resources_from(body)
        klass = @cursor.resource_class
        params = @cursor.params
        resources = klass.collection_from_response(body, client: @cursor.client, hydrated: klass.__send__(:fully_requested_by?, params), query: params)
        id_only? ? stubs_from(resources) : resources
      end

      # The stubs of a page, which hydrate together, a lookup's worth at a time
      #
      # Hydrating one stub looks up the stubs of its batch in one request, rather than every stub of a page of up
      # to a thousand, since the API bills each resource a lookup returns. A resource without a batch lookup, such
      # as a list, whose class BatchFinders does not extend, hydrates each stub on its own.
      #
      # @api private
      # @param resources [Array<Resource>] the resources of the page
      # @return [Array<Resource>] the stubs
      def stubs_from(resources)
        klass = @cursor.resource_class
        client = @cursor.client
        resources.each_slice(BatchFinders::MAX_BATCH_SIZE).flat_map do |slice|
          batch = (Batch.new(klass, slice, client:) if klass.is_a?(BatchFinders))
          slice.map { |resource| klass.__send__(:from_id_in_batch, resource, client:, batch:) }
        end
      end

      # Check whether the cursor requests nothing but identifiers
      # @api private
      # @return [Boolean] true if the fields parameter selects only the identifier, or the endpoint gives nothing else
      def id_only? = @cursor.__send__(:ids_only?) || @cursor.params[@cursor.resource_class.__send__(:fields_key)].eql?(@cursor.resource_class.__send__(:id_key))

      # Build the query parameters for a page, including the previous page token
      #
      # The page before this one is already fetched, since the pages are read in order.
      #
      # @api private
      # @param index [Integer] the zero-based page index
      # @return [Hash{String => Object}, nil] the parameters or nil if the previous page was the last
      # @raise [InvalidAttribute] if the previous page names the token of a page before it as the next
      def params_for(index)
        return @cursor.params if index.zero?

        token = next_token(index - 1) or return
        @cursor.params.merge(@cursor.__send__(:token_param) => token)
      end

      # The token of the page after a page, which fetched no page before it
      #
      # A page that names the token of a page before it as the next would have the pages fetched again for good, and
      # the API bill each of them, so it raises instead.
      #
      # @api private
      # @param index [Integer] the zero-based index of the page, which is fetched
      # @return [String, nil] the token, or nil if the page is the last
      # @raise [InvalidAttribute] if the page names the token of a page before it as the next
      def next_token(index)
        pages = fetched
        token = pages.fetch(index).next_token
        raise InvalidAttribute, format(REPEATED_TOKEN, index:, path: @cursor.path, token:) if pages.take(index).map(&:next_token).include?(token)

        token
      end

      # The query parameters of a page, asking for no more than the resources wanted
      #
      # A cursor over an endpoint without a page size asks for the page as it is. The page size is raised to the
      # smallest the endpoint accepts, but never past the max_results the cursor was given, so a max_results below
      # that smallest page is sent as it was given, for the API to refuse, as an iteration sends it.
      #
      # @api private
      # @param params [Hash{String => Object}] the query parameters of the page
      # @param wanted [Integer] the number of resources wanted
      # @return [Hash{String => Object}] the parameters, with the page size wanted, within the endpoint's limits
      def sized(params, wanted)
        maximum = params["max_results"]
        return params if maximum.nil?

        params.merge("max_results" => [wanted, @cursor.__send__(:min_results)].max.clamp(..Integer(maximum)))
      end

      # Fetch a page in a background thread; errors resurface when the page is requested
      #
      # A page already fetched, or being fetched by another thread, starts no thread, so reading the pages a cursor
      # holds, or reading one page again, starts none.
      #
      # @api private
      # @param index [Integer] the zero-based page index
      # @return [Thread, nil] the background thread, or nil if the page needs none
      def prefetch(index)
        return unless claim(index)

        Thread.new do
          cached(index)
        rescue
          nil
        ensure
          let_go(index)
        end
      end

      # Claim a page for a background thread to fetch
      # @api private
      # @param index [Integer] the zero-based page index
      # @return [Boolean] true if the page was claimed, which no other thread fetches until it is let go
      def claim(index)
        @monitor.synchronize { !@pages.at(index) && !@prefetching.add?(index).nil? }
      end

      # Let go of a page a background thread claimed, once it is done
      # @api private
      # @param index [Integer] the zero-based page index
      # @return [void]
      def let_go(index)
        @monitor.synchronize { @prefetching.delete(index) }
      end
    end
  end
end
