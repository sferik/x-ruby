# frozen_string_literal: true

require "x/core"
require_relative "error"

module X
  # Raised when the API left some of the rules of the filtered stream unchanged, and no block was given for them
  #
  # The API adds or deletes the rules it can and reports the rest, such as a rule the app already has, as errors of a
  # response that otherwise succeeds. StreamingClient#add_rules and StreamingClient#delete_rules yield each of them
  # to a block, and, without one, raise this error rather than drop them, so that a rule that was not added, or a
  # rule a dry run found invalid, is never passed over in silence. The rules that were changed stay changed, so the
  # error holds what the method would have returned, in {#result}, beside the {#problems} the API reported.
  #
  # @api public
  # @example Report the rules that were not added
  #   begin
  #     streaming_client.add_rules(%w[ruby crystal])
  #   rescue X::RulesRejected => e
  #     warn e.problems.map(&:title).join(", ")
  #     added = e.result
  #   end
  class RulesRejected < Streaming::Error
    # The problems the API reported of the rules it did not change
    #
    # @api public
    # @return [Array<Problem>] the problems, frozen, in the order the API reported them
    # @example Read the title of each problem
    #   error.problems.map(&:title) # => ["DuplicateRule"]
    attr_reader :problems

    # What the method would have returned, had it been given a block
    #
    # @api public
    # @return [Array<StreamRule>, Integer, nil] the rules add_rules added, or the number of rules delete_rules deleted,
    #   or nil for an error built without one, such as one a test built
    # @example Read the rules that were added
    #   error.result.map(&:value) # => ["crystal"]
    attr_reader :result

    # Initialize a new RulesRejected
    #
    # Public, so that code that rescues a RulesRejected can be tested with one built by hand, as StreamingClient builds
    # one for the problems of a change of the rules, and raised with a message alone, as any exception is. The message
    # is the one given, or else the title and detail of each problem.
    #
    # @api public
    # @param message [String, nil] the message, or nil for the one the problems give
    # @param problems [Array<Problem>] the problems the API reported
    # @param result [Array<StreamRule>, Integer, nil] what the method would have returned
    # @return [RulesRejected] a new instance
    # @example Create an error
    #   error = X::RulesRejected.new(problems: X::Problem.all_from(body), result: [])
    # @example Raise the error with a message alone, as a test stub may
    #   raise X::RulesRejected, "The rules were not added"
    def initialize(message = nil, problems: [], result: nil)
      @problems = problems.dup.freeze
      @result = result
      super(message || describe(problems))
    end
  end
end
