require "json"
require "uri"

module X
  # Encodes the query strings and bodies of requests, included into Client
  # @api private
  module RequestEncoding
    private

    # Append query parameters to an endpoint
    # @api private
    # @param endpoint [String] the endpoint, with or without a query string
    # @param params [Hash, nil] the query parameters
    # @return [String] the endpoint with the parameters in its query string
    def endpoint_with(endpoint, params)
      query = URI.encode_www_form(params.to_h.compact.transform_values { |value| value.is_a?(Array) ? value.join(",") : value })
      return endpoint if query.empty?

      "#{endpoint}#{endpoint.include?("?") ? "&" : "?"}#{query}"
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
