require "x/core/errors/error"

module X
  # Raised when a resource that was asked for by identifier or name does not exist
  #
  # The API answers a lookup of a resource that is not there with 200 OK and no data, so this is not the NotFound of
  # a 404 response, which an endpoint that is not there raises, and which holds the response that named it.
  #
  # @api public
  class MissingResource < Error
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

  # Raised when the API offers no way to do what was asked, such as looking up lists in a batch
  # @api public
  class UnsupportedOperation < Error; end
end
