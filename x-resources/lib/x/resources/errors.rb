# frozen_string_literal: true

require "x/core"

module X
  module Resources
    # Base error class for the failures of the object layer, which every error x-resources raises of its own descends from
    #
    # It descends from X::Error, so that rescuing the errors of the X API catches one of them as well. The errors
    # that descend from it are named directly under X, as the errors of x-core are, so that this is the one name
    # under X::Resources a rescue reaches for: it catches the failure of the object layer alone.
    #
    # @api public
    class Error < X::Error; end
  end

  # Raised when a resource that was asked for by identifier or name does not exist
  #
  # A lookup of one resource that is not there raises it whether the API answers 200 OK with no data or a 404 that
  # reports the resource as not found, so code that rescues it need not know which. It is not
  # the NotFound of x-core, which holds the response, and which every other 404 raises, such as one from a client
  # pointed at the wrong host or API version; the NotFound of a 404 that reports the resource is the cause of this.
  #
  # It is raised as well when a request that creates a resource, such as X::Post.create, succeeds without returning
  # it, as X::User.current! raises it when users/me returns no user, holding the problems the response reported.
  #
  # @api public
  class MissingResource < Resources::Error
    # The problems the API reported about the resource
    # @api public
    # @return [Array<Problem>] the problems, empty if the API reported none
    # @example Read why a user was not found
    #   error.problems.first&.detail # => "Could not find user with username: [nobody]."
    attr_reader :problems

    # Initialize the error, adding the detail of the first problem to the message
    #
    # @api public
    # @param message [String, nil] the message
    # @param problems [Array<Problem>] the problems the API reported
    # @return [MissingResource] a new error
    # @example Raise the error
    #   raise X::MissingResource.new("Could not find X::User nobody", problems: problems)
    def initialize(message = nil, problems: [])
      explanation = problems.first&.then { |problem| problem.detail || problem.title }
      super(([message, explanation].compact.join(": ") if message || explanation))
      @problems = problems.dup.freeze
    end
  end

  # Raised when a successful response holds what the object layer cannot read as what the API documents
  #
  # It is the base of InvalidAttribute, for one value of a response, and is raised itself for what a response says
  # beside its values, such as a page that names the token of a page before it as the next, which would have the
  # pages requested again for good. It is not the InvalidResponse of x-core, which a body that is not JSON raises,
  # and which holds the response.
  #
  # @api public
  # @example Rescue what the object layer cannot read of a response
  #   begin
  #     user.followers.to_a
  #   rescue X::UnreadableResponse => e
  #     logger.warn(e.message)
  #   end
  class UnreadableResponse < Resources::Error; end

  # Raised when a response holds a value that cannot be read as what the API documents it to be
  #
  # A timestamp that is not ISO 8601, or an identifier that is not one, is read when the attribute or the reference
  # that holds it is read, and the identifier of a resource when the resource is built from the response, so that one
  # value the object layer cannot read raises where it is read, as this error, which descends from X::Error, rather
  # than as the ArgumentError the same value raises when a caller passes it. The cause is the error that refused it.
  #
  # @api public
  class InvalidAttribute < UnreadableResponse; end

  # Raised when a resource that holds no client is asked for what only a request can answer
  #
  # A resource built without a client, such as one Marshal read back, or one built with from_id and no client, holds
  # its attributes, which it reads as any resource does, but cannot hydrate, refresh, page a collection, or act, since
  # each of them is a request, and the client is what makes it. Build the resource with the client: of from_id, or
  # look it up again with a client.
  #
  # @api public
  # @example Hydrate a resource that has a client
  #   X::User.from_id(7_505_382, client: client).hydrate
  class MissingClient < Resources::Error; end

  # Raised when a scan or a count reads the pages its max_pages allows, and the API names a page after them
  #
  # A check that pages through a collection, such as List#member? or User#follows?, and a count of posts, such as
  # X::Post.count_all, read as many pages as the answer takes, and the API bills each one. Given max_pages,
  # each reads no more pages than that, and raises this rather than answer from the pages it read, which would be
  # wrong: a member on a page it did not read, or posts counted on one, would go unseen.
  #
  # @api public
  # @example Give up on a check that would read more than ten pages
  #   begin
  #     list.member?(user, max_pages: 10)
  #   rescue X::PageLimitReached
  #     nil
  #   end
  class PageLimitReached < Resources::Error; end
end
