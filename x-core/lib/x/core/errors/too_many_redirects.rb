# frozen_string_literal: true

require_relative "error"

module X
  # Raised for a response that redirected more times than the client's max_redirects allows
  # @api public
  class TooManyRedirects < Error; end
end
