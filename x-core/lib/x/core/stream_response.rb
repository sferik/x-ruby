# frozen_string_literal: true

require_relative "rate_limit"
require_relative "response_headers"
require_relative "stream_body"

module X
  module Core
    # The response of a request whose body is read as it arrives, which Client#get_stream passes to its block
    #
    # It is passed to the block before its body is read, so it reads the status and headers the API answered with,
    # and the block reads the body with {#read_body}, for as long as it likes. It is x-core's own, rather than the
    # response of the library the client sends its requests with, so that a block written for one release of 1.x
    # reads the response of every other, whatever sends the request.
    #
    # @api public
    class ::X::StreamResponse
      include ResponseHeaders

      # The message of the error a second read of the body raises
      READ_ONCE = "The body of a stream is read once, and read_body has read it, whole or in part. Only a body " \
        "read whole, without a block, is returned again"
      # The message of the error a read of the body raises once the block of get_stream has returned
      READ_OUTSIDE_BLOCK = "The body of a stream is read inside the block of get_stream, which has returned, and " \
        "closed the connection the body is read from"
      # The message of the error a read of a body that was read from the response of the transport raises
      READ_ELSEWHERE = "The body of the stream was read from its http_response, which leaves read_body none to read"
      # The message of the error a read of the body of a response that was frozen deeply raises
      READ_DEEP_FROZEN = "The body of a stream cannot be read from a response that was frozen deeply, with what " \
        "its reads are noted in and the connection the body is read from. A response frozen with freeze is read as " \
        "any other"
      # The end of the message of the IOError Net::HTTP raises for a body it is asked to read again
      TRANSPORT_READ_TWICE = "#read_body called twice"
      private_constant :READ_ONCE, :READ_OUTSIDE_BLOCK, :READ_ELSEWHERE, :READ_DEEP_FROZEN, :TRANSPORT_READ_TWICE

      # What was read of the body of a response, which the response and its copies share
      #
      # It is an object of its own, rather than the state of the response, so that a response that was frozen counts
      # its reads as any other does, and a dup or clone of a response counts them with it: the body they read is one.
      #
      # @api private
      class ReadState
        # Whether read_body has read the body, whole or in part
        # @api private
        # @return [true, nil] true once the body was read
        attr_accessor :read

        # Whether read_body has read the body whole, to return it again
        # @api private
        # @return [true, nil] true once the body was read whole
        attr_accessor :whole

        # Whether the block of Client#get_stream has returned
        #
        # The connection the body is read from is closed once it has.
        #
        # @api private
        # @return [true, nil] true once the block has returned
        attr_accessor :left

        # The body read whole
        # @api private
        # @return [String, nil] the body, or nil for one not read whole, or a response without one
        attr_accessor :body
      end
      private_constant :ReadState

      # @!method headers
      #   The headers of the response
      #
      #   The names are lowercase, and a field the API sent more than once is joined with a comma.
      #   @api public
      #   @return [Hash{String => String}] the headers, frozen
      #   @example Read the content type of a stream
      #     response.headers["content-type"]

      # The URI of the request
      # @api public
      # @return [URI::Generic] the request URI
      # @example Get the path of the request
      #   response.uri.path # => "/2/tweets/sample/stream"
      attr_reader :uri

      # The response itself, as the client received it, with its body not yet read
      #
      # It is an escape hatch, for what this does not read: the status is {#status}, the headers are {#headers}, and
      # the body is read with {#read_body}. It is the response of the transport the client sends its requests with, a
      # Net::HTTPResponse today, and its class is not covered by the compatibility promise of 1.x: a later release of
      # 1.x may send its requests with another library, whose response this then returns. A body read from it, rather
      # than with {#read_body}, raises the errors of its socket as they are, rather than as a NetworkError, which
      # Client#get_stream raises as the block's own, and is not known to {#read_body}, which counts the reads of its
      # own alone: once the body was read from it, in part or whole, {#read_body} reads what is left of it, returns
      # the body it read whole, or raises an Error for a body it left none of.
      #
      # @api public
      # @return [Net::HTTPResponse] the response of the transport
      # @example Read the reason phrase of the status line
      #   response.http_response.message # => "OK"
      attr_reader :http_response

      # Initialize the response of a stream
      #
      # Internal to x-core: it takes the Net::HTTP response of a request, so that it can change within 1.x, as that
      # response may, and is private, so the stream Client#get_stream opens builds it with __send__.
      #
      # @api private
      # @param http_response [Net::HTTPResponse] the successful response, whose body is not yet read
      # @param uri [URI::Generic] the URI of the request
      # @return [StreamResponse] a new instance
      # @example Build the response of a stream
      #   X::StreamResponse.__send__(:new, http_response:, uri: URI("https://api.x.com/2/tweets/sample/stream"))
      def initialize(http_response:, uri:)
        @http_response = http_response
        @uri = uri
        @state = ReadState.new
      end
      private_class_method :new

      # The HTTP status code
      #
      # @api public
      # @return [Integer] the status code
      # @example Get the status code
      #   response.status # => 200
      def status = Integer(http_response.code)

      # The rate limits the response reports in its headers
      #
      # @api public
      # @return [Array<RateLimit>] the 15-minute limit, and the 24-hour app and user limits when reported
      # @example Print how many connections remain in each window
      #   response.rate_limits.each { |limit| puts "#{limit.type}: #{limit.remaining}" }
      def rate_limits = RateLimit.__send__(:all_from, http_response)

      # The 15-minute rate limit of the endpoint
      #
      # For a stream, it counts the connections that may be opened in the window.
      #
      # @api public
      # @return [RateLimit, nil] the rate limit, or nil if the response reports none
      # @example Read how many times a stream may connect again before the limit resets
      #   response.rate_limit&.remaining # => 49
      def rate_limit = rate_limits.find { |limit| limit.type.eql?(RateLimit::RATE_LIMIT_TYPE) }

      # Read the body, a chunk at a time as it arrives, or whole
      #
      # Given a block, each chunk of the body is passed to it as it arrives, until the body ends, which the body of a
      # stream does only when its connection closes. A chunk is whatever arrived, in binary, since it may end within a
      # line, or within a character, which no encoding but binary reads half of. Without a block, the body is read to
      # its end, and returned whole, tagged UTF-8, the encoding of the JSON the API sends, as the body of a
      # {Response} is: a body that is not valid UTF-8 keeps its bytes, so valid_encoding? tells it apart, and scrub
      # replaces what is not UTF-8. A response without a body, such as a 204, has none to return.
      #
      # The body is read once, inside the block of Client#get_stream, since it is read from a connection that is
      # closed once that block returns. A body read whole, without a block, is returned again by each read without a
      # block that follows, as a String of its own. Any other second read raises an Error that says so, with or
      # without a block, after a read that passed the chunks to a block, even one the block left partway through, with
      # break, throw, or an error, or after a read that failed; so does any read once the block of Client#get_stream
      # has returned. The Error is the caller's, not the socket's, so it is neither a NetworkError nor retried. Only
      # the reads of this method are counted: a body read from {#http_response} is not known to it, and a read of a
      # body that was read to its end there, a chunk at a time, raises the same Error, for there is none left. A dup or
      # clone of the response reads the same body, so its reads are counted with those of the response, and a
      # response that was frozen is read as any other is. A response that was frozen deeply, as Ractor.make_shareable
      # freezes one on a Ruby before 4.1, which refuses to share the socket of one, is not: its connection is frozen
      # with it, so a read of a body not yet read raises an Error that says so, while a body read whole before is
      # returned again.
      #
      # An error of the socket the body is read from, such as a connection that dropped, or a read that timed out,
      # raises a NetworkError here, inside the block of Client#get_stream, which may rescue it, and which
      # Client#get_stream raises as it is otherwise. It names the request, and its cause is the error of the socket.
      # An error the block raises is raised as it was, whatever its class.
      #
      # @api public
      # @yieldparam chunk [String] each chunk of the body, as it arrives, in binary
      # @return [String, nil] the body, read whole and tagged UTF-8, or nil for a response without a body, or once a
      #   block was passed each chunk of it
      # @raise [Error] if the body was read before, unless both reads are whole, or the block of Client#get_stream
      #   has returned, or the body was read from {#http_response}, or the response was frozen deeply
      # @raise [NetworkError] if the socket the body is read from fails, as when the connection drops or a read
      #   times out
      # @raise [StandardError] whatever the block raises
      # @example Print the body of a stream as it arrives
      #   response.read_body { |chunk| print chunk }
      # @example Read a body that ends whole
      #   body = response.read_body
      # @example Flush what was read of a stream that dropped
      #   begin
      #     response.read_body { |chunk| file.write(chunk) }
      #   rescue X::NetworkError
      #     file.flush
      #     raise
      #   end
      def read_body(&block)
        raise Error, READ_OUTSIDE_BLOCK if @state.left
        return whole_body if @state.whole && !block
        note_read
        failed = [] #: Array[Exception]
        body = StreamBody.reading(uri, failed) { transport_body(block, failed) }
        return if block

        @state.body = body
        @state.whole = true
        whole_body
      end

      private

      # Note that the body is read, which it is once
      #
      # A response that was frozen deeply, with what its reads are noted in, has nowhere to note it, and no
      # connection to read from that Net::HTTP can read, so its read is refused, rather than raise a FrozenError that
      # names what the reads are counted in.
      #
      # @api private
      # @return [void]
      # @raise [Error] if the body was read before, or the response was frozen deeply
      def note_read
        raise Error, READ_ONCE if @state.read
        raise Error, READ_DEEP_FROZEN if @state.frozen?

        @state.read = true
      end

      # The body read whole, as a String of its own, tagged UTF-8
      #
      # @api private
      # @return [String, nil] the body, or nil for a response without one
      def whole_body = @state.body.dup&.force_encoding(Encoding::UTF_8)

      # Read the body from the response of the transport
      #
      # The transport knows nothing of the reads this counts, nor this of the transport's, so a body the block of
      # Client#get_stream read from {#http_response} is found out here: Net::HTTP raises an IOError for a body it is
      # asked to pass to a block again, which is not an error of the socket, and returns what it passed the chunks to,
      # rather than a String, for one it is asked to return whole.
      #
      # @api private
      # @param block [Proc, nil] the block each chunk is passed to, or nil to read the body whole
      # @param failed [Array<Exception>] the errors of the block, which the error it raises is added to
      # @return [String, nil] the body read whole, or nil for a response without one, or what a block was passed
      # @raise [Error] if the body was read from the response of the transport
      # @raise [StandardError] whatever reading the body raises
      def transport_body(block, failed)
        return http_response.read_body(&StreamBody.passing(block, failed)) if block

        http_response.read_body.tap { |body| raise Error, READ_ELSEWHERE unless body.nil? || body.instance_of?(String) }
      rescue IOError => e
        raise unless e.message.end_with?(TRANSPORT_READ_TWICE) && !failed.include?(e)

        raise Error, READ_ELSEWHERE
      end

      # Note that the block of Client#get_stream has returned
      #
      # The body is read no more after it. Internal to x-core: the stream Client#get_stream opens calls it with
      # __send__ once its block ends, however it ends, since the connection the body is read from is closed then. It
      # is noted in the state the response shares with its copies, so it is noted of a response that was frozen, and
      # of each copy of it.
      #
      # @api private
      # @return [void]
      def leave
        @state.left = true
      end
    end
  end
end
