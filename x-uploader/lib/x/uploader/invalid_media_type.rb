# frozen_string_literal: true

require_relative "error"

module X
  # Error raised when a file's MIME type cannot be determined or is unsupported
  # @api public
  class InvalidMediaType < Uploader::Error; end
end
