# frozen_string_literal: true

require "json"
require "uri"

module X
  module Core
    # Encodes the query strings and bodies of requests
    #
    # Internal to x-core: a client resolves the endpoint of each request, and of each stream it opens, and encodes
    # the body of a request, with it.
    #
    # @api private
    module RequestEncoding
      extend self

      # The slashes that begin an endpoint, which would resolve against the host of the base URL rather than its path
      LEADING_SLASHES = %r{\A/+}
      private_constant :LEADING_SLASHES

      # The message of the error raised for a request given both a body and form fields
      BODY_AND_FORM = "Pass a body or form fields, not both, since a request sends one body"
      private_constant :BODY_AND_FORM

      # The message of the error raised for an endpoint that does not resolve to a URL a request can be sent to
      INVALID_ENDPOINT = "Invalid endpoint %s: %s"
      private_constant :INVALID_ENDPOINT

      # Resolve an endpoint and its query parameters against a base URL
      #
      # An endpoint that is not a valid URL reference, such as one that holds a space or a malformed percent escape,
      # or that resolves to anything but an http or https URL with a host, such as "foo:bar", raises ArgumentError
      # naming it, before any request is built, rather than the URI::InvalidURIError or the ArgumentError of Net::HTTP
      # it would raise as the request was built.
      #
      # @api private
      # @param base_url [String] the base URL the endpoint is relative to
      # @param endpoint [String] the endpoint, with or without a leading slash or a query string
      # @param params [Hash, nil] the query parameters
      # @return [URI::HTTP] the URL of the request
      # @raise [ArgumentError] if the endpoint does not resolve to an http or https URL with a host
      def uri_for(base_url, endpoint, params)
        uri = URI.join(base_url, endpoint_with(endpoint, params))
        return uri if uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?

        raise ArgumentError, format(INVALID_ENDPOINT, endpoint.inspect, "it does not name an http or https URL")
      rescue URI::InvalidURIError
        raise ArgumentError, format(INVALID_ENDPOINT, endpoint.inspect, "it is not a valid URL; escape what a URL may not hold, such as a space")
      end

      # Encode a form as form fields, a String body as given, and any other body as JSON
      #
      # Form fields are encoded as query parameters are, so a field of nil is dropped, an Array is joined with commas,
      # and a Time is given in UTC in the ISO 8601 form the API takes. A body that is not a String, such as a Hash or an Array, is encoded as JSON, since Net::HTTP sends nothing but a
      # String, which it would raise NoMethodError for once the connection was open.
      #
      # @api private
      # @param body [String, Hash, Array, nil] the request body
      # @param form [Hash, nil] the form fields
      # @return [String, nil] the encoded body
      # @raise [ArgumentError] if both a body and form fields are given, which would send one and drop the other
      def encode_body(body, form)
        raise ArgumentError, BODY_AND_FORM if body && form
        return encode_fields(form) unless form.nil?

        case body
        when nil, String then body
        else JSON.generate(body)
        end
      end

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
        query = encode_fields(params.to_h)
        return endpoint if query.empty?

        "#{endpoint}#{endpoint.include?("?") ? "&" : "?"}#{query}"
      end

      # Encode query parameters or form fields
      #
      # A field of nil is dropped, and the others are encoded with query_value.
      #
      # @api private
      # @param fields [Hash] the parameters or fields
      # @return [String] the encoded fields
      def encode_fields(fields) = URI.encode_www_form(fields.compact.transform_values { |value| query_value(value) })

      # Encode a query parameter or form field value
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
    end
    private_constant :RequestEncoding
  end
end
