require_relative "utils"

module X
  # A problem the API reported in a response that otherwise succeeded, such as a referenced post that no longer exists
  # @api public
  class Problem
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
      @attrs = Objects::Utils.deep_freeze(attrs)
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
    #   problem.type # => "https://api.twitter.com/2/problems/resource-not-found"
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
    # @api public
    # @return [String, nil] the resource identifier
    # @example Get the resource identifier
    #   problem.resource_id # => "1"
    def resource_id = attrs["resource_id"]

    # The request parameter the problem concerns
    #
    # @api public
    # @return [String, nil] the parameter, such as ids or pinned_tweet_id
    # @example Get the parameter
    #   problem.parameter # => "pinned_tweet_id"
    def parameter = attrs["parameter"]

    # The value of the parameter the problem concerns
    #
    # @api public
    # @return [Object, nil] the value
    # @example Get the value
    #   problem.value # => "1"
    def value = attrs["value"]

    # Check whether the problem is a resource that was not found
    #
    # @api public
    # @return [Boolean] true for a resource-not-found problem
    # @example Skip the posts that no longer exist
    #   problems.reject(&:not_found?)
    def not_found? = type.to_s.end_with?("/resource-not-found")

    # Summarize the problem for the console
    #
    # @api public
    # @return [String] the class name, title, and detail
    # @example Inspect a problem
    #   problem.inspect # => #<X::Problem Not Found Error: Could not find tweet with pinned_tweet_id: [1].>
    def inspect = "#<#{self.class} #{[title, detail].compact.join(": ")}>"
  end
end
