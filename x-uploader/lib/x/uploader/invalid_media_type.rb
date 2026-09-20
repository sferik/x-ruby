require_relative "error"

module X
  module Uploader
    # Error raised when a file's MIME type cannot be determined or is unsupported
    # @api public
    class InvalidMediaType < Error; end
  end
end
