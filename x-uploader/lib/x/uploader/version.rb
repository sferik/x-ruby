# frozen_string_literal: true

require "rubygems/version"

module X
  # Uploads media, profile images, and banners to the X API
  # @api public
  module Uploader
    # The current version of the x-uploader gem
    VERSION = "0.19.0"

    # The version as a Gem::Version, which compares one release with another
    #
    # VERSION is a String, as a version constant is throughout Ruby, so that what reads it can split it, match it,
    # or send it wherever a String belongs. This builds the Gem::Version that compares it with another version,
    # which a String compares by character rather than by segment.
    #
    # @api public
    # @return [Gem::Version] the version
    # @example Take a path that a later release opened
    #   X::Uploader.gem_version >= Gem::Version.new("1.1")
    def self.gem_version = Gem::Version.new(VERSION)
  end
end
