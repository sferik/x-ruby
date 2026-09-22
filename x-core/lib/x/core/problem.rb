# frozen_string_literal: true

require "json"

module X
  # A problem the API described, in a response that failed or in one that otherwise succeeded
  #
  # The API describes what went wrong the same way whether it refused the request, which raises an {HTTPError}
  # whose {HTTPError#problem} is one of these, or answered it with the resources it could and named the rest as
  # errors, which the object layer reads as the problems of a resource or a page. Code that acts on the reason
  # rather than logging it reads the same object either way.
  #
  # @api public
  class Problem
    # The kinds of resource whose identifiers are numbers, as the API names them
    INTEGER_ID_TYPES = %w[user tweet post list dm_event community poll].freeze
    private_constant :INTEGER_ID_TYPES

    # The raw attributes of the problem
    # @api public
    # @return [Hash{String => Object}] the attributes
    # @example Get the raw attributes
    #   problem.attrs # => {"title" => "Not Found Error", "detail" => "Could not find tweet with pinned_tweet_id: [1].", ...}
    attr_reader :attrs

    # @!method to_h
    #   Alias for attrs, returns the raw attributes
    #   @api public
    #   @return [Hash{String => Object}] the attributes
    #   @example Convert a problem to a hash
    #     problem.to_h
    alias_method :to_h, :attrs

    # Build a problem from the attributes the API reported, if it reported any
    #
    # @api public
    # @param attrs [Hash, nil] the attributes, or nil for a response that described no problem
    # @return [Problem, nil] the problem, or nil for no attributes
    # @example Build a problem from what a body described
    #   X::Problem.from(body["errors"]&.first)
    def self.from(attrs)
      new(attrs) unless attrs.nil?
    end

    # The problems a response body reports
    #
    # @api public
    # @param body [Hash, nil] the parsed response body
    # @return [Array<Problem>] the problems, empty if there are none
    # @example Read the problems of a response
    #   X::Problem.all_from(client.get("users/me"))
    def self.all_from(body)
      entries = Array(body.to_h["errors"]) #: Array[untyped]
      entries.filter_map { |attrs| Hash.try_convert(attrs)&.then { |hash| new(hash) } }.freeze
    end

    # Initialize a problem from the attributes the API reported
    #
    # @api public
    # @param attrs [Hash{String => Object}] the attributes
    # @return [Problem] a new problem
    # @example Build a problem
    #   X::Problem.new({"title" => "Not Found Error"})
    def initialize(attrs)
      @attrs = deep_freeze(attrs)
      freeze
    end

    # The short, general description of the problem
    #
    # @api public
    # @return [String, nil] the title
    # @example Get the title
    #   problem.title # => "Not Found Error"
    def title = attrs["title"]

    # The description of this occurrence of the problem
    #
    # @api public
    # @return [String, nil] the detail
    # @example Get the detail
    #   problem.detail # => "Could not find tweet with pinned_tweet_id: [1]."
    def detail = attrs["detail"]

    # The URI that identifies the kind of problem
    #
    # @api public
    # @return [String, nil] the type
    # @example Get the type
    #   problem.type # => "https://api.x.com/2/problems/resource-not-found"
    def type = attrs["type"]

    # The kind of resource the problem concerns
    #
    # @api public
    # @return [String, nil] the resource type, such as tweet or user
    # @example Get the resource type
    #   problem.resource_type # => "tweet"
    def resource_type = attrs["resource_type"]

    # The identifier of the resource the problem concerns
    #
    # The identifier is an Integer for a user, post, list, direct message, community, or poll, as the id of the
    # resource is, so the two compare equal. What is not such an identifier remains a String: the identifier of a
    # space, place, or media, and the username of a user who was looked up by name.
    #
    # @api public
    # @return [Integer, String, nil] the resource identifier
    # @example Get the resource identifier
    #   problem.resource_id # => 1
    def resource_id = identifier(attrs["resource_id"])

    # The request parameter the problem concerns
    #
    # @api public
    # @return [String, nil] the parameter, such as ids or pinned_tweet_id
    # @example Get the parameter
    #   problem.parameter # => "pinned_tweet_id"
    def parameter = attrs["parameter"]

    # The value of the parameter the problem concerns
    #
    # A value that identifies a resource is an Integer when resource_id is, and anything else is as the API gave it.
    #
    # @api public
    # @return [Object, nil] the value
    # @example Get the value
    #   problem.value # => 1
    def value = identifier(attrs["value"])

    # The message the API gave for a request it refused
    #
    # The errors of a request the API refused carry a message where the problems of a response that succeeded carry
    # a detail, so a problem read from a failed request reads as one of either.
    #
    # @api public
    # @return [String, nil] the message
    # @example Get the message
    #   problem.message # => "Could not authenticate you"
    def message = attrs["message"]

    # Check whether the problem is a resource that was not found
    #
    # @api public
    # @return [Boolean] true for a resource-not-found problem
    # @example Skip the posts that no longer exist
    #   problems.reject(&:not_found?)
    def not_found? = type.to_s.end_with?("/resource-not-found")

    # The attributes, as a JSON encoder and ActiveSupport read them
    #
    # ActiveSupport's Object#as_json would otherwise read the instance variables, which is the same Hash under
    # another name.
    #
    # @api public
    # @return [Hash{String => Object}] the attributes
    # @example Serialize a problem
    #   problem.as_json # => {"title" => "Not Found Error"}
    def as_json(*) = attrs

    # The attributes as JSON
    #
    # @api public
    # @param state [JSON::State, nil] the state a JSON encoder passes, which the attributes are given
    # @return [String] the attributes as a JSON object
    # @example Serialize a problem
    #   problem.to_json # => "{\"title\":\"Not Found Error\"}"
    def to_json(state = nil) = as_json.to_json(state)

    # Summarize the problem for the console
    #
    # A problem the API described in a response that succeeded carries a detail, and one it named among the errors
    # of a request it refused carries a message in its place, so the summary reads whichever of the two it holds.
    #
    # @api public
    # @return [String] the class name, title, and detail, or message
    # @example Inspect a problem of a response that succeeded
    #   problem.inspect # => #<X::Problem Not Found Error: Could not find tweet with pinned_tweet_id: [1].>
    # @example Inspect a problem of a request the API refused
    #   problem.inspect # => #<X::Problem Could not authenticate you>
    def inspect = "#<#{self.class} #{[title, detail || message].compact.join(": ")}>"

    private

    # Read a value as an Integer if it is the numeric identifier of a resource
    # @api private
    # @param value [Object] the value the API gave
    # @return [Object] the identifier as an Integer, or the value as it is
    def identifier(value)
      numeric_identifier?(value) ? Integer(value, 10) : value
    end

    # Check whether a value is the numeric identifier of a resource
    # @api private
    # @param value [Object] the value the API gave
    # @return [Boolean] true for digits that identify, rather than name, a resource whose identifiers are numbers
    def numeric_identifier?(value)
      return false unless INTEGER_ID_TYPES.include?(resource_type) && String === value

      !parameter.to_s.end_with?("username", "usernames") && value.match?(/\A\d+\z/)
    end

    # Copy the attributes with String keys, and freeze them and what they hold
    # @api private
    # @param value [Object] the value
    # @return [Object] the frozen copy
    def deep_freeze(value)
      case value
      when Hash then value.transform_keys(&:to_s).transform_values { |element| deep_freeze(element) }.freeze
      when Array then value.map { |element| deep_freeze(element) }.freeze
      when String then value.dup.freeze
      else value
      end
    end
  end
end
