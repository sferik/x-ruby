# frozen_string_literal: true

require "json"
require "net/http"
require "x/core"
require_relative "callback_error"
require_relative "stream_error"

module X
  module Streaming
    # Reads the lines of a stream the API answered, and decodes each into the object it delivers
    #
    # Internal to x-streaming: StreamingClient reads streams with it.
    #
    # @api private
    class StreamParser
      # Line delimiter for streaming responses
      LINE_DELIMITER = "\r\n"

      # Read a stream the API answered, and yield each object it delivers
      #
      # The request of the stream, which its errors name, is the one the response answers, a GET of its URI.
      #
      # @api private
      # @param response [Net::HTTPResponse] the successful response of the stream, whose body is not yet read
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class, #from_response] the class for parsing JSON objects, or one that builds each object
      #   from the whole line
      # @param client [Client] the client of the stream, which from_response is passed
      # @param on_line [#call] a callable passed each line of JSON before it is decoded
      # @yield [Object] each decoded JSON document from the stream
      # @return [void]
      # @raise [InvalidResponse] if a line of the stream is not JSON, which the error holds as its body
      # @raise [StreamError] if a line holds errors and no data
      # @raise [CallbackError] if on_line, or the object_class that builds each object, raises, so that the error is
      #   not taken for one of the stream
      # @example Process a streaming response
      #   parser.process(response:, array_class: Array, object_class: Hash, client:, on_line: ->(_) {}) { |json| puts json }
      def process(response:, array_class:, object_class:, client:, on_line:, &block)
        decode = lambda do |line|
          tagging_callback_errors do
            on_line.call(line)
            decode_line(line, response:, array_class:, object_class:, client:)
          end
        rescue JSON::ParserError
          raise InvalidResponse.new(http_response: response, body: line, http_method: :get, uri: response.uri)
        end
        read_lines(response:, decode:, &block)
      end

      private

      # Decode a line of the stream, raising for one that holds errors alone
      #
      # A line that holds errors and no data, such as the operational-disconnect X sends before it closes a stream,
      # is not an object the stream delivers, so it raises StreamError, which holds the problems, whatever the
      # objects are built as, rather than reach the block as a Hash that holds no data, or build nothing of it with
      # an object_class that responds to from_response. A line is otherwise decoded as the body of a request is.
      #
      # @api private
      # @param line [String] the line, tagged UTF-8
      # @param response [Net::HTTPResponse] the response of the stream, whose request the error names
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class, #from_response] the class for parsing JSON objects, or one that builds each object
      #   from the whole line
      # @param client [Client] the client of the stream, which from_response is passed
      # @return [Object] the decoded line
      # @raise [JSON::ParserError] if the line is not JSON
      # @raise [StreamError] if the line holds errors and no data
      def decode_line(line, response:, array_class:, object_class:, client:)
        body = JSON.parse(line)
        problems = (Hash === body && !body.key?("data")) ? Problem.all_from(body) : [] #: Array[Problem]
        raise StreamError.new(problems, http_method: :get, uri: response.uri) unless problems.empty?
        return object_class.from_response(body, client:) if object_class.respond_to?(:from_response)

        JSON.parse(line, array_class:, object_class:)
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
      # @raise [StreamError] if the line holds errors alone
      # @raise [CallbackError] if a callback raised any other error
      def tagging_callback_errors
        yield
      rescue JSON::ParserError, StreamError
        raise
      rescue => e
        raise CallbackError, e
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
      # is tagged UTF-8 once it is whole, before on_line, the decoder, or an error reads it. A line that is not valid
      # UTF-8 keeps its bytes, as the body of a request does.
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
    private_constant :StreamParser
  end
end
