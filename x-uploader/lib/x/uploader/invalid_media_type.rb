# frozen_string_literal: true

require_relative "invalid_media"

module X
  # Error raised when a file's MIME type cannot be determined or is unsupported
  #
  # It descends from X::InvalidMedia, so rescuing media the API would refuse catches it.
  #
  # @api public
  class InvalidMediaType < InvalidMedia; end
end
