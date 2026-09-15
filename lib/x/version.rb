# frozen_string_literal: true

require "rubygems/version"

module X
  # The current version of the X gem
  VERSION = "1.0.0"

  # The version as a Gem::Version, which compares one release with another
  #
  # VERSION is a String, as a version constant is throughout Ruby, so that what reads it can split it, match it, or
  # send it wherever a String belongs, such as the release a crash reporter is told. This builds the Gem::Version
  # that compares it with another version, which a String compares by character rather than by segment.
  #
  # @api public
  # @return [Gem::Version] the version
  # @example Take a path that a later release opened
  #   X.gem_version >= Gem::Version.new("1.1")
  def self.gem_version = Gem::Version.new(VERSION)
end
