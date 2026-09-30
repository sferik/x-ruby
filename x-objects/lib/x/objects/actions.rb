# frozen_string_literal: true

require_relative "actions/direct_messages"
require_relative "actions/engagement"
require_relative "actions/lists"
require_relative "actions/posts"
require_relative "actions/relationships"

module X
  module Objects
    # Actions taken as the authenticated user, the modules of which X::Objects::API includes
    #
    # Internal to x-objects: a namespace of the modules API includes into a client, and not itself included, so that
    # the modules it holds are not constants of the client, where the name of one, such as Media, would shadow a
    # constant of the same name in a class that inherits from the client. Include API rather than any of them.
    #
    # @api private
    module Actions
    end
  end
end
