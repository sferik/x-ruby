# frozen_string_literal: true

require_relative "resource"

module X
  # A poll attached to a post
  # @api public
  class Poll < Objects::Resource
    # Every public poll field
    FIELDS = %w[duration_minutes end_datetime id options voting_status].freeze

    # The key under which polls appear in the includes of a response
    #
    # @api private
    # @return [String] the includes key
    # @example Get the includes key
    #   X::Poll.includes_key # => "polls"
    def self.includes_key
      "polls"
    end

    # @!attribute [r] options
    #   The poll options with their positions, labels, and vote counts
    #   @api public
    #   @return [Array<Hash>, nil] the options
    #   @example Get the options
    #     poll.options
    attribute :options

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
