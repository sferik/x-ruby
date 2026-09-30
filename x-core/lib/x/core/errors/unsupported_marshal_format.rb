# frozen_string_literal: true

require_relative "error"

module X
  # Raised when Marshal reads what was written in a format this release does not read
  #
  # What the X gems write with Marshal, such as a resource, a page, or a problem, is plain data led by the number of
  # its format, which every release of 1.x writes, each adding only what an earlier one ignores, so that a cache
  # written by one release of 1.x is read by every other, and one written in another format, as a later major
  # version may write, fails where it is read, rather than read as something it is not. Such a cache is written again.
  #
  # @api public
  # @example Read a cached user again when it was written in another format
  #   begin
  #     Marshal.load(cached)
  #   rescue X::UnsupportedMarshalFormat
  #     Rails.cache.delete("user")
  #   end
  class UnsupportedMarshalFormat < Error; end
end
