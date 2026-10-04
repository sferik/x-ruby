# frozen_string_literal: true

require "x/core"
require_relative "page_limit"
require_relative "utils"

module X
  module Resources
    # The relationships of a user with other users, read as the authenticated user sees them
    #
    # It reads them and changes none: a relationship changes as the authenticated user alone, so the client changes it,
    # as in client.follow(user), rather than a user, which may be anyone.
    #
    # Internal to x-resources: the methods it gives a user, such as follows?, are public API, but the module is only how
    # they are shared, and which classes extend or include it can change within 1.x.
    #
    # @api semipublic
    module Relationships
      # Check whether this user follows a user
      #
      # When either user is the authenticated user, one lookup of the other's connection_status answers.
      # Otherwise the users this user follows are scanned until one matches, up to 1,000 a page, and the
      # API bills every user returned, so checking an account that follows thousands can cost dollars, and max_pages
      # limits the pages the scan reads, raising PageLimitReached rather than read past them. A client that
      # authenticates as the app alone has no authenticated user, which the API refuses to look up, so it scans.
      # Any other failure to look the authenticated user up raises, rather than scan every user this one follows.
      #
      # @api public
      # @param user [User, String, Integer] the user or their identifier
      # @param max_pages [Integer, nil] the most pages of followed users to scan, or nil for no limit
      # @return [Boolean] true if this user follows the user
      # @raise [ArgumentError] if max_pages is neither an Integer of at least 1 nor nil, before a request
      # @raise [PageLimitReached] if the scan reads max_pages pages without the user, and the API names another
      # @example Check whether the authenticated user follows someone, in one lookup
      #   client.current_user!.follows?(other)
      # @example Scan no more than five pages of the users another user follows
      #   X::User.find("jack", client: client).follows?(other, max_pages: 5)
      def follows?(user, max_pages: nil)
        target, max_pages = User.from_id(user), PageLimit.check!(max_pages)
        case authenticated_user_id
        when id then connection_status_of(target).include?("following")
        when target.id then connection_status_of(self).include?("followed_by")
        else PageLimit.scan(following.stubs, target, what: "User#follows?", max_pages:)
        end
      end

      private

      # The identifier of the authenticated user, when the client knows it
      #
      # A client that authenticates as the app alone has no authenticated user, and asks the API for one in vain,
      # so the refusal of the credentials of the client leaves the identifier unknown rather than end the check. Any
      # other error, such as a rate limit, a failure of the API, or of the network, ends it, since a scan in its place
      # would page through every user this one follows, which the API bills.
      #
      # @api private
      # @return [Integer, nil] the identifier, or nil if the client has no current_user_id or cannot read one
      # @raise [X::Error] if the API fails to answer for another reason than the credentials of the client
      def authenticated_user_id
        current = client! #: untyped
        current.current_user_id if current.respond_to?(:current_user_id)
      rescue X::Forbidden, X::Unauthorized
        nil
      end

      # How the authenticated user is connected to a user, in one lookup
      # @api private
      # @param user [User, String, Integer] the user or their identifier
      # @return [Array<String>] the connection statuses, empty if the user was not found
      def connection_status_of(user)
        found = User.find(user, client: client!, "user.fields": "connection_status", "post.fields": nil, expansions: nil)
        Array(found&.connection_status)
      end
    end
    private_constant :Relationships
  end
end
