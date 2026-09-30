# frozen_string_literal: true

require "json"
require_relative "errors/unsupported_marshal_format"

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
    # The number of the format of the state Marshal writes, which every release of 1.x writes
    #
    # A later release of 1.x adds to the state only what an earlier one ignores, parts after those it reads and keys of a
    # Hash it does not read, so that the state one release of 1.x writes is read by every other, earlier or later.
    MARSHAL_FORMAT = 1
    private_constant :MARSHAL_FORMAT

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
    # It is the String the API gave, whatever the kind of resource, since the API names a user by a username as
    # often as by an identifier, and a space, a place, or media by an identifier that is not a number; compare it with
    # the id of a resource as a String, as resource.id.to_s.
    #
    # @api public
    # @return [String, nil] the resource identifier
    # @example Get the resource identifier
    #   problem.resource_id # => "1"
    # @example Check whether a problem is about a user
    #   problem.resource_id.eql?(user.id.to_s)
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
    # It is the value the API gave, as the request sent it, so an identifier is a String, as resource_id is.
    #
    # @api public
    # @return [Object, nil] the value
    # @example Get the value
    #   problem.value # => "1"
    def value = attrs["value"]

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

    # Check whether the problem is an operational-disconnect of a stream
    #
    # X sends one before it closes a stream for its own reasons. A stream reconnects after a line that holds such problems alone, as it does after a connection that dropped.
    #
    # @api public
    # @return [Boolean] true for an operational-disconnect problem
    # @example Tell a disconnect apart from another error of a stream
    #   error.problems.all?(&:disconnect?)
    def disconnect? = type.to_s.end_with?("/operational-disconnect")

    # Check whether another problem is the same problem
    #
    # @api public
    # @param other [Object] the other problem
    # @return [Boolean] true if the other problem is a Problem of the same attributes
    # @example Check whether a response reported a problem before
    #   seen.include?(problem)
    def ==(other) = other.instance_of?(self.class) && attrs.eql?(other.attrs)
    alias_method :eql?, :==

    # The hash of the problem, which equal problems share
    #
    # @api public
    # @return [Integer] the hash
    # @example Count the distinct problems
    #   problems.uniq.size
    def hash = [self.class, attrs].hash

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

    # The state Marshal writes
    #
    # What is written is plain data, led by the number of its format, so that a problem written by one release of 1.x
    # is read by a later one: its attributes, as the API described it.
    #
    # @api public
    # @return [Array(Integer, Hash{String => Object})] the number of the format, then the attributes
    # @example Cache the problems of a response
    #   Rails.cache.write("problems", X::Problem.all_from(body))
    def marshal_dump = [MARSHAL_FORMAT, attrs]

    # Restore a problem Marshal read, frozen as the problem that was written was
    #
    # @api public
    # @param state [Array] the state Marshal wrote
    # @return [void]
    # @raise [UnsupportedMarshalFormat] if the state is of a format this release does not read
    # @example Read cached problems
    #   Marshal.load(Marshal.dump(problem)).title
    def marshal_load(state)
      format, attrs = state
      raise UnsupportedMarshalFormat, "#{self.class} reads format #{MARSHAL_FORMAT} of Marshal, not #{format.inspect}" unless MARSHAL_FORMAT.eql?(format)

      initialize(attrs)
    end

    private

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
