require "json"
require "net/http"
require_relative "response_parser"

module X
  # Handles streaming responses from the X API
  # @api public
  class StreamParser
    # Line delimiter for streaming responses
    LINE_DELIMITER = "\r\n".freeze

    # Process a streaming response and yield parsed JSON objects
    #
    # @api public
    # @param response [Net::HTTPResponse] the HTTP response to stream
    # @param response_parser [ResponseParser] the response parser for error handling
    # @param array_class [Class, nil] the class for parsing JSON arrays
    # @param object_class [Class, nil] the class for parsing JSON objects
    # @yield [Hash, Array] each parsed JSON object from the stream
    # @return [void]
    # @raise [HTTPError] if the response is not successful
    # @example Process a streaming response
    #   handler.process(response: response, response_parser: parser) { |json| puts json }
    def process(response:, response_parser:, array_class: nil, object_class: nil, &block)
      response_parser.parse(response:) unless response.is_a?(Net::HTTPSuccess)

      buffer = +""
      response.read_body do |chunk|
        buffer << chunk
        process_buffer(buffer:, array_class:, object_class:, &block)
      end
      process_remaining(buffer:, array_class:, object_class:, &block)
    end

    private

    # Process complete lines from the buffer
    # @api private
    # @param buffer [String] the accumulated data buffer
    # @param array_class [Class, nil] the class for parsing JSON arrays
    # @param object_class [Class, nil] the class for parsing JSON objects
    # @yield [Hash, Array] each parsed JSON object
    # @return [void]
    def process_buffer(buffer:, array_class:, object_class:, &)
      while (line_end = buffer.index(LINE_DELIMITER))
        line = buffer.slice!(0, line_end) # : String
        buffer.delete_prefix!(LINE_DELIMITER)
        yield_json(line:, array_class:, object_class:, &) unless line.empty?
      end
    end

    # Process any remaining data after the stream ends
    # @api private
    # @param buffer [String] the remaining data buffer
    # @param array_class [Class, nil] the class for parsing JSON arrays
    # @param object_class [Class, nil] the class for parsing JSON objects
    # @yield [Hash, Array] the parsed JSON object
    # @return [void]
    def process_remaining(buffer:, array_class:, object_class:, &)
      buffer.strip!
      yield_json(line: buffer, array_class:, object_class:, &) unless buffer.empty?
    end

    # Parse a line as JSON and yield the result
    # @api private
    # @param line [String] the JSON line to parse
    # @param array_class [Class, nil] the class for parsing JSON arrays
    # @param object_class [Class, nil] the class for parsing JSON objects
    # @yield [Hash, Array] the parsed JSON object
    # @return [void]
    def yield_json(line:, array_class:, object_class:)
      yield JSON.parse(line, array_class:, object_class:)
    end
  end
end
