require_relative "error"

module X
  # Error raised when a file's MIME type cannot be determined or is unsupported
  class InvalidMediaType < Error; end
end
