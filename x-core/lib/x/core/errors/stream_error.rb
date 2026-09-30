# frozen_string_literal: true

require_relative "error"
require_relative "../problem"
require_relative "../request_context"

module X
  module Core
    # Raised for a line of a stream that holds errors and no data
    #
    # A stream sends the problems it has in a line of their own, such as the operational-disconnect X sends before it
    # closes a stream. The line is not an object the stream delivers, so the stream raises this error in place of
    # passing it to its block, whether the objects are Hashes or are built by an object_class.
    #
    # A stream reconnects after a line that holds operational-disconnects alone, as it does after a connection that
    # dropped, and raises this error once it has no reconnects left. After any other problems it stops, and the error
    # reaches the caller, who decides whether to open the stream again. The message names the request, and each
    # problem, and {#problems} holds them, as {HTTPError#problems} holds those of a response the API refused.
    # {#http_method} and {#uri} are the request of the stream.
    #
    # @api public
    # @example Report the problems that stopped a stream
    #   begin
    #     client.streaming.stream("tweets/search/stream") { |post| handle(post) }
    #   rescue X::StreamError => e
    #     warn e.problems.map(&:title).join(", ")
    #   end
    class ::X::StreamError < Error
      include RequestContext

      # The problems the line of the stream held
      #
      # @api public
      # @return [Array<Problem>] the problems, frozen, in the order the line held them
      # @example Read the title of each problem
      #   error.problems.map(&:title) # => ["operational-disconnect"]
      attr_reader :problems

      # Initialize a new StreamError
      #
      # Public, so that code that rescues a StreamError can be tested with one built by hand, as StreamParser builds one
      # for a line of a stream. The error names the request, when given one, as x-core names the request of the stream.
      #
      # @api public
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
end
