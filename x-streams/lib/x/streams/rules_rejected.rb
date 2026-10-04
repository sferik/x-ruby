# frozen_string_literal: true

require "x/core"
require_relative "error"

module X
  # Raised when the API rejected some of the rules of the filtered stream, and no block was given for them
  #
  # The API reports the rules it does not add or delete, such as a rule that is invalid, as errors of a
  # response that otherwise succeeds. StreamingClient#add_rules and StreamingClient#delete_rules yield each of them
  # to a block, and, without one, raise this error rather than drop them, so that a rule that was not added, or a
  # rule a dry run found invalid, is never passed over in silence. A rule the app already has is not one the API
  # rejected, so add_rules raises nothing for it, and it is neither among the {#problems} nor the rules {#added}. The
  # rules that were changed stay changed, so the error holds what the method would have returned, the rules add_rules
  # added in {#added}, or the number of rules delete_rules deleted in {#deleted_count}, beside the {#problems} the
  # API reported. The API may add none of the rules it is given alongside one it rejects, and report that one alone, so
  # {#added}, and not the {#problems}, says which rules were added.
  #
  # @api public
  # @example Report the rules that were not added
  #   begin
  #     streaming_client.add_rules(["ruby", "from:"])
  #   rescue X::RulesRejected => e
  #     warn e.problems.map(&:title).join(", ")
  #     added = e.added # => [], when the API added none of the rules alongside the one it rejected
  #   end
  class RulesRejected < Streams::Error
    # The problems the API reported of the rules it rejected
    #
    # A rule the app already had is not among them, since the API did not reject it.
    #
    # @api public
    # @return [Array<Problem>] the problems, frozen, in the order the API reported them
    # @example Read the title of each problem
    #   error.problems.map(&:title) # => ["UnprocessableEntity"]
    attr_reader :problems

    # The rules add_rules added
    #
    # They are what add_rules would have returned, had it been given a block, so a rule the app already had is not
    # among them: StreamingClient#rules reads it.
    #
    # @api public
    # @return [Array<StreamRule>, nil] the rules, frozen, or nil for an error delete_rules raised, or one built without
    #   them, such as one a test built
    # @example Read the rules that were added
    #   error.added.map(&:value) # => [], when the API added none of the rules alongside the one it rejected
    attr_reader :added

    # The number of rules delete_rules deleted
    #
    # It is what delete_rules would have returned, had it been given a block.
    #
    # @api public
    # @return [Integer, nil] the number, or nil for an error add_rules raised, or one built without it, such as one a
    #   test built
    # @example Read the number of rules that were deleted
    #   error.deleted_count # => 1
    attr_reader :deleted_count

    # Initialize a new RulesRejected
    #
    # Public, so that code that rescues a RulesRejected can be tested with one built by hand, as StreamingClient builds
    # one for the problems of a change of the rules, and raised with a message alone, as any exception is. The message
    # is the one given, or else the title and detail of each problem.
    #
    # @api public
    # @param message [String, nil] the message, or nil for the one the problems give
    # @param problems [Array<Problem>] the problems the API reported of the rules it rejected
    # @param added [Array<StreamRule>, nil] the rules add_rules added
    # @param deleted_count [Integer, nil] the number of rules delete_rules deleted
    # @return [RulesRejected] a new instance
    # @example Create an error
    #   error = X::RulesRejected.new(problems: X::Problem.all_from(body), added: [])
    # @example Raise the error with a message alone, as a test stub may
    #   raise X::RulesRejected, "The rules were not added"
    def initialize(message = nil, problems: [], added: nil, deleted_count: nil)
      @problems = problems.dup.freeze
      @added = added.dup.freeze
      @deleted_count = deleted_count
      super(message || describe(problems))
    end
  end
end
