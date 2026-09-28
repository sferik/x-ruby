# frozen_string_literal: true

require_relative "actions/direct_messages"
require_relative "actions/engagement"
require_relative "actions/lists"
require_relative "actions/posts"
require_relative "actions/relationships"

module X
  module Objects
    module API
      # Actions taken as the authenticated user, mixed into a client through API
      #
      # Internal to x-objects: X::Objects::API includes it, and its methods are public API of the client that includes
      # API, but the module is only how they are grouped, so include API rather than this module alone.
      #
      # @api private
      module Actions
        include Posts
        include Lists
        include DirectMessages
        include Relationships
        include Engagement
      end
    end
  end
end
