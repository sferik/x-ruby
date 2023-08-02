module X
  class Error < ::StandardError; end
  class ClientError < Error; end
  class AuthenticationError < ClientError; end
  class BadRequestError < ClientError; end
  class ForbiddenError < ClientError; end
  class NotFoundError < ClientError; end
  class TooManyRequestsError < ClientError; end
  class ServerError < Error; end
  class ServiceUnavailableError < ServerError; end
end
