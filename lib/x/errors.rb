module X
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class ServerError < Error; end
end
