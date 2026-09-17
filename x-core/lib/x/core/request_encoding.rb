require "json"
require "uri"

module X
  # Encodes the query strings and bodies of requests, included into Client
  # @api private
  module RequestEncoding
    # The slashes that begin an endpoint, which would resolve against the host of the base URL rather than its path
    LEADING_SLASHES = %r{\A/+}
    private_constant :LEADING_SLASHES

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

    # Encode a form as form fields, a Hash as JSON, and any other body as given
    # @api private
    # @param body [String, Hash, nil] the request body
    # @param form [Hash, nil] the form fields
    # @return [String, nil] the encoded body
    def encode_body(body, form)
      return URI.encode_www_form(form) unless form.nil?

      body.is_a?(Hash) ? JSON.generate(body) : body
    end
  end
end
