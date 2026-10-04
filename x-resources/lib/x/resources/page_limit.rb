# frozen_string_literal: true

require_relative "errors"

module X
  module Resources
    # The limit of the pages a scan or a count reads, which the max_pages of each sets
    #
    # A scan, such as List#member?, and a count of the full archive, such as X::Post.count_all, read as many pages as
    # the answer takes, and the API bills each one, so max_pages limits them, raising PageLimitReached rather than
    # read past it, or answer from the pages it read.
    #
    # @api private
    module PageLimit
      extend self

      # The message of the error raised for a max_pages that is neither a count of pages nor nil
      INVALID_MAX_PAGES = "max_pages must be an Integer of at least 1, or nil for no limit, not %p"
      # The message of the error raised for a scan or a count that read the pages its max_pages allows
      PAGE_LIMIT_REACHED = "%<what>s read the %<max_pages>d pages max_pages allows, and the API names another"
      private_constant :INVALID_MAX_PAGES, :PAGE_LIMIT_REACHED

      # Check that a limit of pages is a count of at least one page, or nil for no limit
      #
      # @api private
      # @param max_pages [Object] the limit
      # @return [Integer, nil] the limit
      # @raise [ArgumentError] if the limit is neither an Integer of at least 1 nor nil
      # @example Check a limit of ten pages
      #   X::Resources::PageLimit.check!(10) # => 10
      def check!(max_pages)
        return max_pages if max_pages.nil? || (max_pages.instance_of?(Integer) && max_pages.positive?)

        raise ArgumentError, format(INVALID_MAX_PAGES, max_pages)
      end

      # Raise for a scan or a count that read the pages its limit allows
      #
      # It raises only when the API names a page after them, since a scan or a count that read every page is done.
      #
      # @api private
      # @param what [String] what read the pages, which the error names
      # @param read [Integer] the number of pages read
      # @param max_pages [Integer, nil] the limit, or nil for none
      # @param next_token [String, nil] the token of the page after the last read, or nil for none
      # @return [void]
      # @raise [PageLimitReached] if the pages read reach the limit, and the API names a page after them
      # @example Stop a scan at its tenth page
      #   X::Resources::PageLimit.reached!("List#member?", read: 10, max_pages: 10, next_token: "7140w")
      def reached!(what, read:, max_pages:, next_token:)
        return unless read.eql?(max_pages) && next_token

        raise PageLimitReached, format(PAGE_LIMIT_REACHED, what:, max_pages:)
      end

      # Scan the pages of a cursor until one holds a resource
      #
      # It reads no more pages than a limit allows.
      #
      # @api private
      # @param cursor [Cursor] the cursor
      # @param resource [Resource] the resource to look for
      # @param what [String] what scans, which the error names
      # @param max_pages [Integer, nil] the most pages to read, or nil for no limit
      # @return [Boolean] true if a page holds the resource
      # @raise [PageLimitReached] if the pages read reach the limit without the resource, and the API names another
      # @example Scan the members of a list for a user, ten pages at most
      #   X::Resources::PageLimit.scan(list.members.stubs, user, what: "List#member?", max_pages: 10)
      def scan(cursor, resource, what:, max_pages:)
        cursor.each_page.with_index(1) do |page, read|
          return true if page.include?(resource)

          reached!(what, read:, max_pages:, next_token: page.next_token)
        end
        false
      end
    end
    private_constant :PageLimit
  end
end
