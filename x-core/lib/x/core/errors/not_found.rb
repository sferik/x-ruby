# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 404 Not Found response
  #
  # The API sends one for an endpoint it does not serve. It answers a lookup of a resource that does not exist with
  # 200 OK and no data, or with a 404 that reports the resource as not found, and a request of x-core raises that
  # 404 as this error too. The finders of x-resources read either answer as a missing resource; see
  # X::MissingResource.
  #
  # @api public
  class NotFound < ClientError; end
end
