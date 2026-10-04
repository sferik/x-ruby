# frozen_string_literal: true

require_relative "error"

module X
  # Raised for media the API would refuse, before any request: a file that does not exist, and media that cannot be
  # read, holds nothing, or is larger than the API takes
  #
  # The media of an upload is often given by a user, so it is told apart from a mistake in the arguments of a call,
  # such as a media category that does not exist, which raises ArgumentError: code that uploads what a user gives
  # rescues this, and X::InvalidMediaType, which descends from it, for media of a type the API does not take, without
  # rescuing the ArgumentError of its own mistakes. One whose cause is an error of the system, such as Errno::EMFILE
  # or Errno::EIO, says the machine could not read the media, not that the media is wrong.
  #
  # It descends from X::Uploads::Error, and so from X::Error, so rescuing the failures of an upload catches it.
  #
  # @api public
  class InvalidMedia < Uploads::Error; end
end
