# frozen_string_literal: true

module X
  module Core
    # The headers of a response, read from the response it holds, included into Response and HTTPError
    #
    # Internal to x-core: it gives a summary of a response, and the error of a failed one, the same headers.
    #
    # @api private
    module ResponseHeaders
      # The headers of the response
      #
      # The names are lowercase, whatever case the API sent them in, since HTTP field names mean the same in any
      # case, so a header is read here by the name it is written with here. A field the API sent more than once
      # is joined with a comma, as HTTP joins the lines of a repeated field.
      #
      # @api public
      # @return [Hash{String => String}] the headers, frozen
      # @example Read how long the API took to answer
      #   response.headers["x-response-time"]
      def headers = http_response.to_hash.transform_values { |values| values.join(", ") }.freeze
    end
  end
end
