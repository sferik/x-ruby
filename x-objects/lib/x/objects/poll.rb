# frozen_string_literal: true

require_relative "resource"

module X
  # A poll attached to a post
  #
  # The API offers no lookup of polls, so a poll is read from the response of the post that expanded it, and the class
  # answers no finder. from_id builds one from its identifier, which a poll the response did not expand is built as too,
  # and which compares equal to the poll it identifies, but hydrate and refresh raise UnsupportedOperation for one that
  # is not hydrated, since there is nothing to look it up with.
  #
  # @api public
  class Poll < Resource
    # Every public poll field
    #
    # A minor release may add to it the fields the API adds, so that a lookup asks for them too; see
    # {Resource#hydrated?} for what that means for a resource looked up with a list of fields of its own.
    FIELDS = %w[duration_minutes end_datetime id options voting_status].freeze

    # The default query parameters, which request every field
    #
    # The API offers no lookup of polls, so they are requested by the posts that expand them, which ask for these
    # fields, and a poll a response included with all of them is hydrated.
    #
    # @api public
    # @return [Hash{String => Array<String>}] the default query parameters
    # @example Get the default parameters
    #   X::Poll.default_params # => {"poll.fields" => [...]}
    def self.default_params = {"poll.fields" => FIELDS}

    # The key under which polls appear in the includes of a response
    #
    # @api private
    # @return [String] the includes key
    # @example Get the includes key
    #   X::Poll.__send__(:includes_key) # => "polls"
    def self.includes_key
      "polls"
    end
    private_class_method :includes_key

    # @!attribute [r] options
    #   The poll options with their positions, labels, and vote counts
    #   @api public
    #   @return [Array<Hash>] the options, empty if there are none
    #   @example Get the options
    #     poll.options
    attribute :options, :list

    # @!attribute [r] duration_minutes
    #   The duration of the poll in minutes
    #   @api public
    #   @return [Integer, nil] the duration in minutes
    #   @example Get the duration
    #     poll.duration_minutes
    attribute :duration_minutes

    # @!attribute [r] end_datetime
    #   The time when the poll ends
    #   @api public
    #   @return [Time, nil] the end time
    #   @example Get the end time
    #     poll.end_datetime
    attribute :end_datetime, :time

    # @!attribute [r] voting_status
    #   The voting status: open or closed
    #   @api public
    #   @return [String, nil] the voting status
    #   @example Get the voting status
    #     poll.voting_status
    attribute :voting_status
  end
end
