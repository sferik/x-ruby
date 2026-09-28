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
    # It is the one module of the object layer to include. The modules it includes, those of API::Lookups and
    # API::Actions, are internal: their methods are public API of the client that includes API, but how they are
    # grouped can change within 1.x, and some need the methods of another, such as current_user_id. So are the
    # modules the resource classes extend and include, such as Finders and Relationships: the methods they give a
    # resource class are public API, the modules are not.
    #
    # @api public
    module API
      include Lookups
      include Actions
    end
  end
end
