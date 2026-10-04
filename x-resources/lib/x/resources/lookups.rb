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
  module Resources
    # Lookups, searches, and collections, the modules of which X::Resources::API includes
    #
    # Internal to x-resources: a namespace of the modules API includes into a client, and not itself included, so that
    # the modules it holds are not constants of the client, where the name of one, such as Media, would shadow a
    # constant of the same name in a class that inherits from the client. Include API rather than any of them.
    #
    # @api private
    module Lookups
    end
    private_constant :Lookups
  end
end
