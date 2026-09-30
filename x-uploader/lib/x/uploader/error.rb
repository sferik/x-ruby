# frozen_string_literal: true

require "x/core"

module X
  module Uploader
    # Base error class for the failures of an upload, which every error x-uploader raises of its own descends from
    #
    # It descends from X::Error, so that rescuing the errors of the X API catches an upload failure as it did before.
    # The errors that descend from it are named directly under X, as the errors of x-core are, so that this is the
    # one name under X::Uploader a rescue reaches for.
    #
    # It catches the errors x-uploader raises of its own: media the API would refuse, raised before any request, and
    # the failures after media was uploaded, which hold the media. It does not catch the X::Error of a request the
    # API refused, or that got no response, before there was media to hold, such as the X::BadRequest of the request
    # that initializes an upload, or of an image sent in a single request, nor the ArgumentError of a mistake in the
    # arguments of a call. Rescue X::Error to catch every failure of an upload.
    #
    # @api public
    class Error < X::Error; end
  end
end
