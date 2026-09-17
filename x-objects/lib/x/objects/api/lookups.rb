require_relative "lookups/communities"
require_relative "lookups/direct_messages"
require_relative "lookups/lists"
require_relative "lookups/media"
require_relative "lookups/posts"
require_relative "lookups/spaces"
require_relative "lookups/users"

module X
  module Objects
    module API
      # Lookups, searches, and collections, mixed into a client through API
      # @api public
      module Lookups
        include Users
        include Posts
        include Lists
        include Media
        include Spaces
        include Communities
        include DirectMessages
      end
    end
  end
end
