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
    # @param response_parser [ResponseParser] the response parser for errors and decoding
    # @param array_class [Class, nil] the class for parsing JSON arrays
    # @param object_class [Class, nil] the class for parsing JSON objects, or a class that builds objects from
    #   each whole document (see {ResponseParser#decode})
    # @param client [Client, nil] the client that made the request
    # @yield [Object] each decoded JSON document from the stream
    # @return [void]
    # @raise [HTTPError] if the response is not successful
    # @example Process a streaming response
    #   handler.process(response: response, response_parser: parser) { |json| puts json }
    def process(response:, response_parser:, array_class: nil, object_class: nil, client: nil, &block)
      response_parser.parse(response:) unless response.is_a?(Net::HTTPSuccess)

      decode = ->(line) { response_parser.decode(line, array_class:, object_class:, client:) }
      buffer = +""
      response.read_body do |chunk|
        buffer << chunk
        process_buffer(buffer:, decode:, &block)
      end
      process_remaining(buffer:, decode:, &block)
    end

    private

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
