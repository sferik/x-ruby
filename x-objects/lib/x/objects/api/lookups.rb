# frozen_string_literal: true

require_relative "lookups/communities"
require_relative "lookups/direct_messages"
require_relative "lookups/lists"
require_relative "lookups/media"
require_relative "lookups/posts"
require_relative "lookups/spaces"
require_relative "lookups/trends"
require_relative "lookups/users"

module X
  module Objects
    module API
      # Lookups, searches, and collections, mixed into a client through API
      #
      # Internal to x-objects: X::Objects::API includes it, and its methods are public API of the client that includes
      # API, but the module is only how they are grouped, so include API rather than this module alone.
      #
      # @api private
      module Lookups
        include Users
        include Posts
        include Lists
        include Media
        include Spaces
        include Communities
        include DirectMessages
        include Trends
      end
    end
  end
end
