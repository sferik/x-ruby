module X
  # The base class of every error the X gems raise
  # @api public
  class Error < StandardError; end

  # Raised when a resource that was asked for by identifier or name does not exist
  # @api public
  class ResourceNotFound < Error
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
    # @return [ResourceNotFound] a new error
    # @example Raise the error
    #   raise X::ResourceNotFound.new("Could not find X::User nobody", problems: problems)
    def initialize(message = nil, problems: [])
      explanation = problems.first&.then { |problem| problem.detail || problem.title }
      super(([message, explanation].compact.join(": ") if message || explanation))
      @problems = problems.dup.freeze
    end
  end
end
