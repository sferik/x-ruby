# frozen_string_literal: true

require "json"
require "net/http"
require_relative "errors/stream_callback_error"
require_relative "errors/stream_error"
require_relative "problem"
require_relative "response_parser"

module X
  module Core
    # Handles streaming responses from the X API
    #
    # Internal to x-core: StreamingClient reads streams with it.
    #
    # @api private
    class StreamParser
      # Line delimiter for streaming responses
      LINE_DELIMITER = "\r\n"

      # Process a streaming response and yield parsed JSON objects
      #
      # @api private
      # @param response [Net::HTTPResponse] the HTTP response to stream
      # @param response_parser [ResponseParser] the response parser for errors and decoding
      # @param array_class [Class, nil] the class for parsing JSON arrays
      # @param object_class [Class, nil] the class for parsing JSON objects, or a class that builds objects from
      #   each whole document (see {ResponseParser#decode})
      # @param client [Client, nil] the client that made the request
      # @param on_body [#call, nil] a callable called before a failed response raises, and passed each line of JSON
      #   before it is decoded
      # @param request [Net::HTTPRequest, nil] the request the stream answers, which its errors name
      # @yield [Object] each decoded JSON document from the stream
      # @return [void]
      # @raise [HTTPError] if the response is not successful
      # @raise [InvalidResponse] if a line of the stream is not JSON, which the error holds as its body
      # @raise [StreamError] if a line holds errors and no data, and an object_class that responds to from_response
      #   builds the objects, which would build nothing of it
      # @raise [StreamCallbackError] if on_body, or the object_class that builds each object, raises, so that the
      #   connection raises that error rather than take it for a network error and reconnect
      # @example Process a streaming response
      #   handler.process(response: response, response_parser: parser) { |json| puts json }
      def process(response:, response_parser:, array_class: nil, object_class: nil, client: nil, on_body: nil, request: nil, &block)
        raise_unless_successful(response:, response_parser:, on_body:, request:)
        decode = lambda do |line|
          tagging_callback_errors do
            on_body&.call(line)
            decode_line(line, response_parser:, array_class:, object_class:, client:, request:)
          end
        rescue JSON::ParserError
          raise InvalidResponse.new(http_response: response, body: line, request:)
        end
        read_lines(response:, decode:, &block)
      end

      private

      # Raise the error of a failed response, after passing it to on_body
      #
      # The body of a failed response is read whole, by on_body or by the error, so it is tagged UTF-8 before either
      # reads it, as the body of a request is; see {Connection#perform}.
      #
      # @api private
      # @param response [Net::HTTPResponse] the HTTP response
      # @param response_parser [ResponseParser] the response parser that raises the error
      # @param on_body [#call, nil] a callable called before the error is raised
      # @param request [Net::HTTPRequest, nil] the request the response answers, which the error names
      # @return [void]
      # @raise [HTTPError] if the response is not successful
      # @raise [StreamCallbackError] if on_body raises
      def raise_unless_successful(response:, response_parser:, on_body:, request:)
        return if response.is_a?(Net::HTTPSuccess)

        response.body_encoding = Encoding::UTF_8
        tagging_callback_errors { on_body&.call }
        response_parser.parse(response:, request:)
      end

      # Decode a line of the stream, raising for one that holds errors alone
      #
      # An object_class that responds to from_response builds each object from the data of a line, so it would build
      # nothing of a line that holds errors and no data, such as the operational-disconnect X sends before it closes
      # a stream, and the errors would be lost. That line raises StreamError, which holds them. A line is otherwise
      # decoded as the body of a request is, so a stream that yields each line as a Hash yields that line too.
      #
      # @api private
      # @param line [String] the line, tagged UTF-8
      # @param response_parser [ResponseParser] the response parser that decodes the line
      # @param array_class [Class, nil] the class for parsing JSON arrays
      # @param object_class [Class, nil] the class for parsing JSON objects, or a class that builds objects from
      #   each whole document
      # @param client [Client, nil] the client that made the request
      # @param request [Net::HTTPRequest, nil] the request the stream answers, which the error names
      # @return [Object] the decoded line
      # @raise [JSON::ParserError] if the line is not JSON
      # @raise [StreamError] if the line holds errors and no data, for an object_class that responds to from_response
      def decode_line(line, response_parser:, array_class:, object_class:, client:, request:)
        return response_parser.decode(line, array_class:, object_class:) unless object_class.respond_to?(:from_response)

        body = JSON.parse(line)
        problems = (Hash === body && !body.key?("data")) ? Problem.all_from(body) : [] #: Array[Problem]
        raise StreamError.new(problems, request:) unless problems.empty?

        object_class.from_response(body, client:)
      end

      # Run the callbacks of a line, tagging the error one of them raises
      #
      # The errors a socket raises are the errors a stream reconnects after, so a callback that raises one of them is
      # told apart from a connection that dropped. A JSON::ParserError is left as it is, so that a line that is not
      # JSON still raises InvalidResponse, which a stream reconnects after, and so is a StreamError, which the stream
      # raised rather than a callback, and which reaches the caller.
      #
      # @api private
      # @yield [] runs the callbacks
      # @return [Object] what the callbacks returned
      # @raise [JSON::ParserError] if the line is not JSON
      # @raise [StreamError] if the line holds errors alone, and the objects are built with from_response
      # @raise [StreamCallbackError] if a callback raised any other error
      def tagging_callback_errors
        yield
      rescue JSON::ParserError, StreamError
        raise
      rescue => e
        raise StreamCallbackError, e
      end

      # Read the body in chunks and yield each line as it completes
      # @api private
      # @param response [Net::HTTPResponse] the HTTP response
      # @param decode [Proc] the lambda that decodes a line
      # @yield [Object] each decoded JSON document
      # @return [void]
      def read_lines(response:, decode:, &)
        buffer = +""
        response.read_body do |chunk|
          buffer << chunk
          process_buffer(buffer:, decode:, &)
        end
        process_remaining(buffer:, decode:, &)
      end

      # Process complete lines from the buffer
      # @api private
      # @param buffer [String] the accumulated data buffer
      # @param decode [Proc] decodes a line of JSON
      # @yield [Object] each decoded JSON document
      # @return [void]
      def process_buffer(buffer:, decode:, &)
        while (line_end = buffer.index(LINE_DELIMITER))
          line = buffer.slice!(0, line_end) # : String
          buffer.delete_prefix!(LINE_DELIMITER)
          yield_json(line:, decode:, &) unless line.empty?
        end
      end

      # Process any remaining data after the stream ends
      # @api private
      # @param buffer [String] the remaining data buffer
      # @param decode [Proc] decodes a line of JSON
      # @yield [Object] the decoded JSON document
      # @return [void]
      def process_remaining(buffer:, decode:, &)
        buffer.strip!
        yield_json(line: buffer, decode:, &) unless buffer.empty?
      end

      # Decode a line of JSON and yield the result
      #
      # Net::HTTP passes the body of a stream in binary chunks, and a chunk can end within a character, so each line
      # is tagged UTF-8 once it is whole, before on_body, the decoder, or an error reads it. A line that is not valid
      # UTF-8 keeps its bytes, as the body of a request does; see {Connection#perform}.
      #
      # @api private
      # @param line [String] the JSON line to decode
      # @param decode [Proc] decodes a line of JSON
      # @yield [Object] the decoded JSON document
      # @return [void]
      def yield_json(line:, decode:)
        yield decode.call(line.force_encoding(Encoding::UTF_8))
      end
    end
  end
end
