# frozen_string_literal: true

require_relative "serialization"
require_relative "utils"
require_relative "value_equality"
require_relative "value_marshalling"

module X
  module Objects
    # A rule of the filtered stream that a post the stream delivered matched: the identifier the API gave the rule, and
    # the tag it is labelled with
    #
    # The stream names a rule a post matched by its identifier and its tag alone, not by the value it matches, so this is
    # not an X::StreamRule, which holds that value. It names the rule to X::StreamingClient#delete_rules by its
    # identifier, as rule.id, or as rule.to_h, and it is found among the rules X::StreamingClient#rules reads by
    # the identifier they share.
    #
    # It is frozen, compares equal to a rule of the same attributes, and matches a pattern of its identifier and tag,
    # as in rule in {tag: "ruby"}. Its attributes are what the stream sent of the rule, as those of a resource are, so
    # to_h, as_json, and to_json give them as the stream did, whatever the stream comes to send of a rule beside its
    # identifier and tag.
    #
    # @api public
    class ::X::MatchingRule
      include Serialization
      include ValueEquality
      include ValueMarshalling

      # The attributes of the rule, as the stream sends them
      #
      # The identifier is a String, as the stream sends it, and a rule without a tag holds none.
      #
      # @api public
      # @return [Hash{String => Object}] the attributes, frozen
      # @example Get the attributes
      #   rule.attrs # => {"id" => "1165037377523306498", "tag" => "ruby"}
      attr_reader :attrs

      # @!method to_h
      #   Alias for attrs, returns the attributes of the rule, which X::StreamingClient#delete_rules takes
      #   @api public
      #   @return [Hash{String => Object}] the attributes
      #   @example Delete the rule a post matched
      #     streaming_client.delete_rules(post.matching_rules.first.to_h)
      alias_method :to_h, :attrs

      # Initialize a rule a post matched from the attributes the stream sent of it
      #
      # The identifier and tag are read as it is built, so that a rule that holds either as something else raises
      # here, rather than from its readers.
      #
      # @api public
      # @param attrs [Hash{String => Object}] the attributes, which name the identifier as id, as an Integer or as the
      #   String the stream sends, and the tag as tag, unless the rule has none
      # @return [MatchingRule] the frozen rule
      # @raise [ArgumentError] if the attributes are not a Hash, the identifier names no number, or the tag is neither a
      #   String nor nil
      # @example Build a rule a post matched
      #   X::MatchingRule.new({"id" => "1165037377523306498", "tag" => "ruby"})
      def initialize(attrs)
        @attrs = Utils.deep_freeze(Utils.attributes!(attrs))
        id
        raise ArgumentError, "tag must be a String, not #{tag.inspect}" unless tag.nil? || tag.is_a?(String)

        freeze
      end

      # The identifier the API gave the rule
      #
      # The API sends it as a String, and it is read as an Integer, as the identifier of a stream rule is.
      #
      # @api public
      # @return [Integer] the identifier
      # @example Get the identifier
      #   rule.id # => 1165037377523306498
      def id = Integer(attrs["id"].to_s, 10)

      # The tag the rule is labelled with
      # @api public
      # @return [String, nil] the tag, or nil for a rule without one
      # @example Get the tag
      #   rule.tag # => "ruby"
      def tag = attrs["tag"]

      # The identifier and tag of the rule, which a pattern matches against
      #
      # @api public
      # @param keys [Array<Symbol>, nil] the keys the pattern asks for, or nil for both
      # @return [Hash{Symbol => Integer, String, nil}] the identifier and tag the pattern asks for
      # @example Keep the posts that matched the rule tagged ruby
      #   post.matching_rules.any? { |rule| rule in {tag: "ruby"} }
      def deconstruct_keys(keys) = Utils.deconstruct(self, keys, %i[id tag])

      # Summarize the rule for the console
      #
      # @api public
      # @return [String] the class name, identifier, and tag
      # @example Inspect a rule
      #   rule.inspect # => #<X::MatchingRule id=1165037377523306498 tag="ruby">
      def inspect = "#<#{self.class} id=#{id} tag=#{tag.inspect}>"
    end
  end
end
