# frozen_string_literal: true

require_relative "api/actions"
require_relative "api/lookups"

module X
  module Objects
    # The resource methods mixed into a client that responds to get, post, put, and delete
    #
    # The x gem includes it into X::Client. With x-core and x-objects alone, or with a client of your own,
    # include it yourself: X::Client.include(X::Objects::API).
    #
    # @api public
    module API
      include Lookups
      include Actions
    end
  end
end
