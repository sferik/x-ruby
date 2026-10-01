# frozen_string_literal: true

require_relative "resource"

module X
  # A topic a space is about
  #
  # The API offers no lookup of topics, so a topic is read from the response of the space that expanded it, and the
  # class answers no finder. from_id builds one from its identifier, which a topic the response did not expand is built
  # as too, and which compares equal to the topic it identifies, but hydrate and refresh raise UnsupportedOperation for
  # one that is not hydrated, since there is nothing to look it up with.
  #
  # @api public
  class Topic < Resource
    # Every public topic field
    #
    # A minor release may add to it the fields the API adds, so that a lookup asks for them too; see
    # {Resource#hydrated?} for what that means for a resource looked up with a list of fields of its own.
    FIELDS = %w[description id name].freeze

    # The default query parameters, which request every field
    #
    # The API offers no lookup of topics, so they are requested by the spaces that expand them, which ask for these
    # fields, and a topic a response included with all of them is hydrated.
    #
    # @api public
    # @return [Hash{String => Array<String>}] the default query parameters
    # @example Get the default parameters
    #   X::Topic.default_params # => {"topic.fields" => [...]}
    def self.default_params = {"topic.fields" => FIELDS}

    # The key under which topics appear in the includes of a response
    #
    # @api private
    # @return [String] the includes key
    # @example Get the includes key
    #   X::Topic.__send__(:includes_key) # => "topics"
    def self.includes_key
      "topics"
    end
    private_class_method :includes_key

    # @!attribute [r] name
    #   The name of the topic
    #   @api public
    #   @return [String, nil] the name
    #   @example Get the name
    #     topic.name # => "Technology"
    attribute :name

    # @!attribute [r] description
    #   What the topic is about
    #   @api public
    #   @return [String, nil] the description
    #   @example Get the description
    #     topic.description # => "All about technology"
    attribute :description
  end
end
