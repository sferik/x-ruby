# frozen_string_literal: true

require "x/core"
require "x/uploads"
require "x/streams"
require "x/resources"
require_relative "x/version"

module X
  Client.include(Resources::API)
  Client.include(Uploads::API)
  Client.include(Streams::API)
end
