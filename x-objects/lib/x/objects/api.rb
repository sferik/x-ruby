# frozen_string_literal: true

require_relative "actions"
require_relative "lookups"

module X
  module Objects
    # The resource methods mixed into a client that responds to get, post, put, and delete
    #
    # The x gem includes it into X::Client. With x-core and x-objects alone, or with a client of your own,
    # include it yourself: X::Client.include(X::Objects::API).
    #
    # It is the one module of the object layer to include. The modules it includes, those of Lookups and Actions,
    # are internal: their methods are public API of the client that includes API, but how they are grouped can change
    # within 1.x, and some need the methods of another, such as current_user_id. So are the modules the resource
    # classes extend and include, such as Finders and Relationships: the methods they give a resource class are public
    # API, the modules are not.
    #
    # Neither API nor a module it includes holds a constant, as a constant of a module is a constant of each class
    # that includes it: a class that inherits from the client and names Media, or Users, reads the constant the name
    # reads anywhere else, not a module of the object layer.
    #
    # @api public
    module API
      include Lookups::Users
      include Lookups::Posts
      include Lookups::Lists
      include Lookups::Media
      include Lookups::Spaces
      include Lookups::Communities
      include Lookups::DirectMessages
      include Lookups::Trends
      include Actions::Posts
      include Actions::Lists
      include Actions::DirectMessages
      include Actions::Relationships
      include Actions::Engagement
    end
  end
end
