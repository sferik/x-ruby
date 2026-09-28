# frozen_string_literal: true

require "x/core/errors/error"
require "x/core/errors/unsupported_operation"

module X
  module Objects
    # Base error class for the failures of the object layer, which every error x-objects raises of its own descends from
    #
    # It descends from X::Error, so that rescuing the errors of the X API catches one of them as well. The errors
    # that descend from it are named directly under X, as the errors of x-core are, so that this is the one name
    # under X::Objects a rescue reaches for: it catches the failure of the object layer alone.
    #
    # @api public
    class Error < X::Error; end
  end

  # Raised when a resource that was asked for by identifier or name does not exist
  #
  # The API answers a lookup of a resource that is not there with 200 OK and no data, so this is not the NotFound of
  # a 404 response, which an endpoint that is not there raises, and which holds the response that named it.
  #
  # @api public
  class MissingResource < Objects::Error
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

  # Raised when a response holds a value that cannot be read as what the API documents it to be
  #
  # A timestamp that is not ISO 8601, or an identifier that is not one, is read when the attribute or the reference
  # that holds it is read, and the identifier of a resource when the resource is built from the response, so that one
  # value the object layer cannot read raises where it is read, as this error, which descends from X::Error, rather
  # than as the ArgumentError the same value raises when a caller passes it. The cause is the error that refused it.
  #
  # @api public
  class InvalidAttribute < Objects::Error; end

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
  class MissingClient < Objects::Error; end
end
