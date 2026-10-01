# frozen_string_literal: true

require "x/core"

module X
  module Streaming
    # Base error class for the failures of a stream, which every error x-streaming raises of its own descends from
    #
    # It descends from X::Error, so that rescuing the errors of the X API catches the failure of a stream too. The
    # errors that descend from it are named directly under X, as the errors of x-core are, so that this is the one name
    # under X::Streaming a rescue reaches for.
    #
    # It catches the errors x-streaming raises of its own: a line of a stream that held errors and no data, and rules
    # of the filtered stream the API left unchanged. It does not catch the X::Error of a request the API refused, or
    # that got no response, such as the X::NetworkError of a stream that dropped with no reconnects left, nor the
    # ArgumentError of a mistake in the arguments of a call. Rescue X::Error to catch every failure of a stream.
    #
    # @api public
    class Error < X::Error; end
  end
end
