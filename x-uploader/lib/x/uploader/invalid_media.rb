# frozen_string_literal: true

require_relative "error"

module X
  # Raised for media the API would refuse, before any request: media that cannot be read, holds nothing, or is
  # larger than the API takes
  #
  # The media of an upload is often given by a user, so it is told apart from a mistake in the arguments of a call,
  # such as a media category that does not exist, which raises ArgumentError: code that uploads what a user gives
  # rescues this, and X::InvalidMediaType, which descends from it, for media of a type the API does not take, without
  # rescuing the ArgumentError of its own mistakes.
  #
  # It descends from X::Uploader::Error, and so from X::Error, so rescuing the failures of an upload catches it.
  #
  # @api public
  class InvalidMedia < Uploader::Error; end
end
