require_relative "error"

module X
  # Error raised when too many redirects are encountered
  class TooManyRedirects < Error; end
end
