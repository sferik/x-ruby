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
      # @api public
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
