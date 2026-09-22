# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 404 Not Found response, which the API sends for an endpoint it does not serve
  #
  # A lookup of a resource that does not exist is answered with 200 OK and no data, so this is not what a missing
  # user or post raises; see X::MissingResource.
  #
  # @api public
  class NotFound < ClientError; end
end
