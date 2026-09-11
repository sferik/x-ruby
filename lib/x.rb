require "x/core"
require "x/objects"
require_relative "x/version"

module X
  Client.include(Objects::API)
end
