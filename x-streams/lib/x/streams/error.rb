# frozen_string_literal: true

require "x/core"

module X
  module Streams
    # Base error class for the failures of a stream, which every error x-streams raises of its own descends from
    #
    # It descends from X::Error, so that rescuing the errors of the X API catches the failure of a stream too. The
    # errors that descend from it are named directly under X, as the errors of x-core are, so that this is the one name
    # under X::Streams a rescue reaches for.
    #
    # It catches the errors x-streams raises of its own: a line of a stream that held errors and no data, and rules
    # of the filtered stream the API left unchanged. It does not catch the X::Error of a request the API refused, or
    # that got no response, such as the X::NetworkError of a stream that dropped with no reconnects left, nor the
    # ArgumentError of a mistake in the arguments of a call. Rescue X::Error to catch every failure of a stream.
    #
    # @api public
    class Error < X::Error
      private

      # The title and detail of each problem, separated by commas
      #
      # It is the message of an error built of problems without a message of its own.
      #
      # @api private
      # @param problems [Array<Problem>] the problems
      # @return [String, nil] the title and detail of each problem, or nil for none
      def describe(problems)
        problems.map { |problem| [problem.title, problem.detail || problem.message].compact.join(": ") }.join(", ") unless problems.empty?
      end
    end
  end
end
