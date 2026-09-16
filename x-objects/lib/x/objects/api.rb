require_relative "api/actions"
require_relative "api/lookups"

module X
  module Objects
    # The resource methods mixed into a client that responds to get, post, and delete
    # @api public
    module API
      include Lookups
      include Actions
    end
  end
end
