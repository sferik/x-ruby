# frozen_string_literal: true

require "x/core"
require_relative "error"

module X
  # Raised when a response of an upload holds none of the data it describes the media with
  #
  # The API answers an upload, a status check, and a change of metadata with what it acted on, under the data of
  # the response. A response that succeeded without it holds nothing an upload can go on, so the uploaders raise
  # this rather than fail later on what is missing. So does one whose media is not what the API documents, such as an
  # identifier that is not one, or processing information of another type, as a gateway in front of the API might
  # answer with, rather than fail as it is read. A response that holds problems in place of the data, as one for
  # media X does not know of does, names the reason in them, which the error holds, and names in its message.
  #
  # It descends from X::Uploads::Error, and so from X::Error, so rescuing the failures of an upload catches it.
  #
  # @api public
  class MissingMediaData < Uploads::Error
    # The problems the response reported in place of the data
    # @api public
    # @return [Array<Problem>] the problems, frozen, empty for a response that reported none
    # @example Tell media X does not know of
    #   error.problems.any?(&:not_found?)
    attr_reader :problems

    # Initialize the error with the reason X gave for holding no data
    #
    # The message is the one given, then the detail, or else the message or the title, of the first problem the
    # response reported, as "The response of the status check holds no media: Could not find media".
    #
    # @api public
    # @param message [String, nil] the message, or nil for the reason alone
    # @param problems [Array<Problem>] the problems the response reported in place of the data
    # @return [MissingMediaData] a new error
    # @example Raise the error for a response that holds problems in place of media
    #   raise X::MissingMediaData.new("The response holds no media", problems: X::Problem.all_from(response))
    # @example Raise the error with a message alone, as a test stub may
    #   raise X::MissingMediaData, "The response holds no media"
    def initialize(message = nil, problems: [])
      @problems = problems.dup.freeze
      reason = problems.first&.then { |problem| problem.detail || problem.message || problem.title }
      parts = [message, reason].compact
      super((parts.join(": ") unless parts.empty?))
    end
  end
end
