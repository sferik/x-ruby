require "x/core/errors/error"

module X
  module Uploader
    # Error raised when a file's MIME type cannot be determined or is unsupported
    # @api public
    class InvalidMediaType < Error; end
  end

  # The name of Uploader::InvalidMediaType before the uploaders moved under X::Uploader
  InvalidMediaType = Uploader::InvalidMediaType
  deprecate_constant :InvalidMediaType
end
