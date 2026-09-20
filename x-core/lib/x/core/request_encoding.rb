require "json"
require "uri"

module X
  module Core
    # Encodes the query strings and bodies of requests, included into Client
    # @api private
    module RequestEncoding
      # The slashes that begin an endpoint, which would resolve against the host of the base URL rather than its path
      LEADING_SLASHES = %r{\A/+}
      private_constant :LEADING_SLASHES

      # The message of the error raised for a request given both a body and form fields
      BODY_AND_FORM = "Pass a body or form fields, not both, since a request sends one body".freeze
      private_constant :BODY_AND_FORM

      private

      # Append query parameters to an endpoint, relative to the base URL
      #
      # An endpoint resolves against the base URL, which would drop the path of the base URL, such as the /2/ of the
      # API version, for an endpoint that begins with a slash, so leading slashes are removed.
      #
      # @api private
      # @param endpoint [String] the endpoint, with or without a leading slash or a query string
      # @param params [Hash, nil] the query parameters
      # @return [String] the endpoint, without leading slashes, with the parameters in its query string
      def endpoint_with(endpoint, params)
        endpoint = endpoint.sub(LEADING_SLASHES, "")
        query = URI.encode_www_form(params.to_h.compact.transform_values { |value| query_value(value) })
        return endpoint if query.empty?

        "#{endpoint}#{endpoint.include?("?") ? "&" : "?"}#{query}"
      end

      # Encode a query parameter value
      #
      # An Array is joined with commas, and a Time is given in UTC in the ISO 8601 form the API takes.
      #
      # @api private
      # @param value [Object] the value
      # @return [Object] the encoded value
      def query_value(value)
        case value
        when Array then value.join(",")
        when Time then value.getutc.iso8601
        else value
        end
      end

      # Encode a form as form fields, a String body as given, and any other body as JSON
      #
      # A body that is not a String, such as a Hash or an Array, is encoded as JSON, since Net::HTTP sends nothing but a
      # String, which it would raise NoMethodError for once the connection was open.
      #
      # @api private
      # @param body [String, Hash, Array, nil] the request body
      # @param form [Hash, nil] the form fields
      # @return [String, nil] the encoded body
      # @raise [ArgumentError] if both a body and form fields are given, which would send one and drop the other
      def encode_body(body, form)
        raise ArgumentError, BODY_AND_FORM if body && form
        return URI.encode_www_form(form) unless form.nil?

        case body
        when nil, String then body
        else JSON.generate(body)
        end
      end
    end
  end
end
