# frozen_string_literal: true

require "json"
require "net/http"
require_relative "errors/stream_callback_error"
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
      # @yield [Object] each decoded JSON document from the stream
      # @return [void]
      # @raise [HTTPError] if the response is not successful
      # @raise [InvalidResponse] if a line of the stream is not JSON, which the error holds as its body
      # @raise [StreamCallbackError] if on_body, or the object_class that builds each object, raises, so that the
      #   connection raises that error rather than take it for a network error and reconnect
      # @example Process a streaming response
      #   handler.process(response: response, response_parser: parser) { |json| puts json }
      def process(response:, response_parser:, array_class: nil, object_class: nil, client: nil, on_body: nil, &block)
        raise_unless_successful(response:, response_parser:, on_body:)
        decode = lambda do |line|
          tagging_callback_errors do
            on_body&.call(line)
            response_parser.decode(line, array_class:, object_class:, client:)
          end
        rescue JSON::ParserError
          raise InvalidResponse.new(http_response: response, body: line)
        end
        read_lines(response:, decode:, &block)
      end

      private

      # Raise the error of a failed response, after passing it to on_body
      # @api private
      # @param response [Net::HTTPResponse] the HTTP response
      # @param response_parser [ResponseParser] the response parser that raises the error
      # @param on_body [#call, nil] a callable called before the error is raised
      # @return [void]
      # @raise [HTTPError] if the response is not successful
      # @raise [StreamCallbackError] if on_body raises
      def raise_unless_successful(response:, response_parser:, on_body:)
        return if response.is_a?(Net::HTTPSuccess)

        tagging_callback_errors { on_body&.call }
        response_parser.parse(response:)
      end

      # Run the callbacks of a line, tagging the error one of them raises
      #
      # The errors a socket raises are the errors a stream reconnects after, so a callback that raises one of them is
      # told apart from a connection that dropped. A JSON::ParserError is left as it is, so that a line that is not
      # JSON still raises InvalidResponse, which a stream reconnects after.
      #
      # @api private
      # @yield [] runs the callbacks
      # @return [Object] what the callbacks returned
      # @raise [JSON::ParserError] if the line is not JSON
      # @raise [StreamCallbackError] if a callback raised any other error
      def tagging_callback_errors
        yield
      rescue JSON::ParserError
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
      # @api private
      # @param line [String] the JSON line to decode
      # @param decode [Proc] decodes a line of JSON
      # @yield [Object] the decoded JSON document
      # @return [void]
      def yield_json(line:, decode:)
        yield decode.call(line)
      end
    end
  end
end
