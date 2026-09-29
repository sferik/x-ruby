# frozen_string_literal: true

require_relative "error"
require_relative "../problem"
require_relative "../request_context"

module X
  # Raised for a line of a stream that holds errors and no data, when the stream builds its objects with an
  # object_class
  #
  # A stream sends the problems it has in a line of their own, such as the operational-disconnect X sends before it
  # closes a stream. An object_class that builds an object from the data of each line, as the resource classes of
  # x-objects do, would build nothing of it, and the problems would be lost, so the stream raises this error in
  # place of passing its block nil. A stream that yields each line as a Hash yields that line too, errors and all.
  #
  # The stream does not reconnect after it: it stops, and the error reaches the caller, who decides whether to open
  # the stream again. The message names the request, and each problem, and {#problems} holds them, as
  # {HTTPError#problem} holds the one of a response the API refused. {#http_method} and {#uri} are the request of
  # the stream.
  #
  # @api public
  # @example Open a stream again after X disconnected it
  #   begin
  #     client.streaming.stream("tweets/search/stream", object_class: X::Post) { |post| handle(post) }
  #   rescue X::StreamError => e
  #     retry if e.problems.any? { |problem| problem.title.eql?("operational-disconnect") }
  #     raise
  #   end
  class StreamError < Error
    include Core::RequestContext

    # The problems the line of the stream held
    #
    # @api public
    # @return [Array<Problem>] the problems, frozen, in the order the line held them
    # @example Read the title of each problem
    #   error.problems.map(&:title) # => ["operational-disconnect"]
    attr_reader :problems

    # Initialize a new StreamError
    #
    # Internal to x-core: StreamParser raises it for a line of a stream, and it takes the Net::HTTP request of the
    # stream, so that it can change within 1.x, as that request may.
    #
    # @api private
    # @param problems [Array<Problem>] the problems the line held
    # @param request [Net::HTTPRequest, nil] the request of the stream, which the error names
    # @return [StreamError] a new instance
    # @example Create an error
    #   error = X::StreamError.new(X::Problem.all_from(body), request: request)
    def initialize(problems, request: nil)
      @problems = problems.dup.freeze
      name_request(request)
      super(message_naming_request(problems.map { |problem| [problem.title, problem.detail || problem.message].compact.join(": ") }.join(", ")))
    end
  end
end
