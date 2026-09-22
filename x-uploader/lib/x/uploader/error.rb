# frozen_string_literal: true

require "x/core/errors/error"

module X
  module Uploader
    # Base error class for the failures of an upload, which every error x-uploader raises of its own descends from
    #
    # It descends from X::Error, so that rescuing the errors of the X API catches an upload failure as it did before.
    # The errors that descend from it are named directly under X, as the errors of x-core are, so that this is the
    # one name under X::Uploader a rescue reaches for: it catches the failure of an upload alone.
    #
    # @api public
    class Error < X::Error; end
  end
end
