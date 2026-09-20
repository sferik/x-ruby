require "x/core/errors/error"

module X
  module Uploader
    # Base error class for the failures of an upload, which every error x-uploader raises of its own descends from
    #
    # It descends from X::Error, so that rescuing the errors of the X API catches an upload failure as it did before.
    #
    # @api public
    class Error < X::Error; end
  end
end
