# frozen_string_literal: true

require_relative "error"

module X
  module Uploader
    # Raised when a response of an upload holds none of the data it describes the media with
    #
    # The API answers an upload, a status check, and a change of metadata with what it acted on, under the data of
    # the response. A response that succeeded without it holds nothing an upload can go on, so the uploaders raise
    # this rather than fail later on what is missing.
    #
    # It descends from X::Uploader::Error, and so from X::Error, so rescuing the failures of an upload catches it.
    #
    # @api public
    class MissingData < Error; end
  end
end
