require_relative "bad_request_error"
require_relative "authentication_error"
require_relative "forbidden_error"
require_relative "not_found_error"
require_relative "too_many_requests_error"
require_relative "server_error"
require_relative "service_unavailable_error"

module X
  module Errors
    ERROR_CLASSES = {
      400 => BadRequestError,
      401 => AuthenticationError,
      403 => ForbiddenError,
      404 => NotFoundError,
      429 => TooManyRequestsError,
      500 => ServerError,
      503 => ServiceUnavailableError
    }.freeze

    NETWORK_ERRORS = [
      Errno::ECONNREFUSED,
      Net::OpenTimeout,
      Net::ReadTimeout
    ].freeze
  end
end
