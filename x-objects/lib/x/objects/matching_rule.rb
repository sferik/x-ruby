# frozen_string_literal: true

require_relative "serialization"
require_relative "value_equality"
require_relative "value_marshalling"

module X
  # A rule of the filtered stream that a post the stream delivered matched: the identifier the API gave the rule, and
  # the tag it is labelled with
  #
  # The stream names a rule a post matched by its identifier and its tag alone, not by the value it matches, so this is
  # not an X::StreamRule, which holds that value. It names the rule to X::StreamingClient#delete_stream_rules by its
  # identifier, as rule.id, or as rule.to_h, and it is found among the rules X::StreamingClient#stream_rules reads by
  # the identifier they share.
  #
  # It is frozen, compares equal to a rule of the same identifier and tag, and matches a pattern of them, as in
  # rule in {tag: "ruby"}. Its attributes are what the stream sent of the rule, as those of a resource are, so to_h,
  # as_json, and to_json give them as the stream did.
  #
  # @api public
  class MatchingRule
    include Objects::Serialization
    include Objects::ValueEquality
    include Objects::ValueMarshalling

    # The attributes of the rule, as the stream sends them
    #
    # The identifier is a String, as the stream sends it, and a rule without a tag holds none.
    #
    # @api public
    # @return [Hash{String => String}] the attributes, frozen
    # @example Get the attributes
    #   rule.attrs # => {"id" => "1165037377523306498", "tag" => "ruby"}
    attr_reader :attrs

    # @!method to_h
    #   Alias for attrs, returns the attributes of the rule, which X::StreamingClient#delete_stream_rules takes
    #   @api public
    #   @return [Hash{String => String}] the attributes
    #   @example Delete the rule a post matched
    #     streaming_client.delete_stream_rules(post.matching_rules.first.to_h)
    alias_method :to_h, :attrs

    # The identifier the API gave the rule
    #
    # The API sends it as a String, and it is read as an Integer, as the identifier of a stream rule is.
    #
    # @api public
    # @return [Integer] the identifier
    # @example Get the identifier
    #   rule.id # => 1165037377523306498
    attr_reader :id

    # The tag the rule is labelled with
    # @api public
    # @return [String, nil] the tag, or nil for a rule without one
    # @example Get the tag
    #   rule.tag # => "ruby"
    attr_reader :tag

    # Initialize a rule a post matched
    #
    # @api public
    # @param id [Integer, String] the identifier the API gave the rule, as an Integer or as the String the API sends
    # @param tag [String, nil] the tag the rule is labelled with, or nil for none
    # @return [MatchingRule] the frozen rule
    # @raise [ArgumentError] if the identifier names no number, or the tag is neither a String nor nil
    # @example Build a rule a post matched
    #   X::MatchingRule.new(id: "1165037377523306498", tag: "ruby")
    def initialize(id:, tag: nil)
      @id = Integer(id.to_s, 10)
      @tag = (String.try_convert(tag) || raise(ArgumentError, "tag must be a String, not #{tag.inspect}")).dup.freeze unless tag.nil?
      @attrs = {"id" => @id.to_s.freeze, "tag" => @tag}.compact.freeze
      freeze
    end

    # The identifier and tag of the rule, which a pattern matches against
    #
    # @api public
    # @param _keys [Array<Symbol>, nil] the keys the pattern names
    # @return [Hash{Symbol => Integer, String, nil}] the identifier and tag
    # @example Keep the posts that matched the rule tagged ruby
    #   post.matching_rules.any? { |rule| rule in {tag: "ruby"} }
    def deconstruct_keys(_keys) = {id:, tag:}

    # Summarize the rule for the console
    #
    # @api public
    # @return [String] the class name, identifier, and tag
    # @example Inspect a rule
    #   rule.inspect # => #<X::MatchingRule id=1165037377523306498 tag="ruby">
    def inspect = "#<#{self.class} id=#{id} tag=#{tag.inspect}>"

    private

    # Build the rule of the attributes Marshal read, as the constructor builds it
    # @api private
    # @param attrs [Hash{String => String}] the attributes
    # @return [void]
    def restore(attrs) = initialize(id: attrs.fetch("id"), tag: attrs["tag"])
  end
end
