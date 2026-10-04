# frozen_string_literal: true

require "json"
require "x/core"
require_relative "callback_error"
require_relative "stream_error"

module X
  module Streams
    # Reads the lines of a stream the API answered, and decodes each into the object it delivers
    #
    # Internal to x-streams: StreamingClient reads streams with it.
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
      # @param response [StreamResponse] the successful response of the stream, whose body is not yet read
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class, #from_response] the class for parsing JSON objects, or one that builds each object
      #   from the whole line
      # @param client [Client] the client of the stream, which from_response is passed
      # @param on_line [#call] a callable passed each line of JSON before it is decoded
      # @param on_keep_alive [#call] a callable called for each keep-alive, the empty line X sends a quiet stream
      # @yield [Object] each decoded JSON document from the stream
      # @return [void]
      # @raise [InvalidResponse] if a line of the stream is not JSON, which the error holds as its body
      # @raise [StreamError] if a line holds errors and no data
      # @raise [CallbackError] if on_line, or the object_class that builds each object, raises, so that the error is
      #   not taken for one of the stream
      # @example Process a streaming response
      #   parser.process(response:, array_class: Array, object_class: Hash, client:, on_line: ->(_) {}, on_keep_alive: -> {}) { |json| puts json }
      def process(response:, array_class:, object_class:, client:, on_line:, on_keep_alive:, &block)
        decode = lambda do |line|
          tagging_callback_errors { on_line.call(line) }
          body = parse_line(line, response:)
          tagging_callback_errors { build(body, array_class:, object_class:, client:) }
        end
        read_lines(response:, decode:, on_keep_alive:, &block)
      end

      private

      # Parse a line of the stream, raising for one not JSON or holding errors alone
      #
      # A line that holds errors and no data, such as the operational-disconnect X sends before it closes a stream,
      # is not an object the stream delivers, so it raises StreamError, which holds the problems, whatever the
      # objects are built as, rather than reach the block as a Hash that holds no data, or build nothing of it with
      # an object_class that responds to from_response.
      #
      # Only this parse is the stream's own, so only a line it cannot parse raises InvalidResponse, which a stream
      # reconnects after: a JSON::ParserError of on_line or of the object_class is theirs, and stops the stream.
      #
      # @api private
      # @param line [String] the line, tagged UTF-8
      # @param response [StreamResponse] the response of the stream, whose request the errors name
      # @return [Object] the parsed line
      # @raise [InvalidResponse] if the line is not JSON, which the error holds as its body
      # @raise [StreamError] if the line holds errors and no data
      def parse_line(line, response:)
        body = JSON.parse(line)
        problems = (Hash === body && !body.key?("data")) ? Problem.all_from(body) : [] #: Array[Problem]
        raise StreamError.new(problems:, http_method: :get, uri: response.uri) unless problems.empty?

        body
      rescue JSON::ParserError
        raise InvalidResponse.new(http_response: response.http_response, body: line, http_method: :get, uri: response.uri)
      end

      # Build the object a line delivers, as the body of a request is decoded
      #
      # The line was parsed once already, into Hashes and Arrays, so it is built from what that parse gave rather than
      # parsed again.
      #
      # @api private
      # @param body [Object] the line, parsed
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class, #from_response] the class for parsing JSON objects, or one that builds each object
      #   from the whole line
      # @param client [Client] the client of the stream, which from_response is passed
      # @return [Object] the object
      def build(body, array_class:, object_class:, client:)
        return object_class.from_response(body, client:) if object_class.respond_to?(:from_response)

        rebuild(body, array_class:, object_class:)
      end

      # Build a parsed value into the array_class and object_class given
      #
      # Each is built as JSON.parse builds it: an object into a new object_class, which is given each of its pairs with
      # []=, in order, and an array into a new array_class, which is given each of its elements with <<, in order,
      # each built in turn. Any other value is what the parse gave.
      #
      # @api private
      # @param value [Object] the parsed value
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class] the class for parsing JSON objects
      # @return [Object] the value, built
      def rebuild(value, array_class:, object_class:)
        case value
        when Hash then value.each_with_object(object_class.new) { |(key, item), object| object[key] = rebuild(item, array_class:, object_class:) }
        when Array then value.each_with_object(array_class.new) { |item, array| array << rebuild(item, array_class:, object_class:) }
        else value
        end
      end

      # Run a callback of a line, tagging the error it raises
      #
      # The errors a socket raises are the errors a stream reconnects after, as is the InvalidResponse of a line that
      # is not JSON, so a callback that raises one of them, or a JSON::ParserError of its own, is told apart from a
      # connection that dropped.
      #
      # @api private
      # @yield [] runs the callback
      # @return [Object] what the callback returned
      # @raise [CallbackError] if the callback raised an error
      def tagging_callback_errors
        yield
      rescue => e
        raise CallbackError, e
      end

      # Read the body in chunks and yield each line as it completes
      #
      # X ends each line it sends, so what is left when the stream ends without a line ending is a line the stream was
      # cut off within, as when the server closes the connection mid-line. It is dropped rather than parsed, which would
      # raise InvalidResponse, and back off as from a server error, for a stream that ended, and it is not passed to
      # on_line, which would report it as an object the API bills: the stream ends as a dropped stream does.
      #
      # @api private
      # @param response [StreamResponse] the response of the stream
      # @param decode [Proc] the lambda that decodes a line
      # @param on_keep_alive [#call] a callable called for each empty line
      # @yield [Object] each decoded JSON document
      # @return [void]
      def read_lines(response:, decode:, on_keep_alive:, &)
        buffer = +""
        response.read_body do |chunk|
          buffer << chunk
          process_buffer(buffer:, decode:, on_keep_alive:, &)
        end
      end

      # Process complete lines from the buffer
      # @api private
      # @param buffer [String] the accumulated data buffer
      # @param decode [Proc] decodes a line of JSON
      # @param on_keep_alive [#call] a callable called for each empty line
      # @yield [Object] each decoded JSON document
      # @return [void]
      def process_buffer(buffer:, decode:, on_keep_alive:, &)
        while (line_end = buffer.index(LINE_DELIMITER))
          line = buffer.slice!(0, line_end) # : String
          buffer.delete_prefix!(LINE_DELIMITER)
          line.empty? ? on_keep_alive.call : yield_json(line:, decode:, &)
        end
      end

      # Decode a line of JSON and yield the result
      #
      # The body of a stream arrives in binary chunks, and a chunk can end within a character, so each line
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
