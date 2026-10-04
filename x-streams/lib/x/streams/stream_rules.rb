# frozen_string_literal: true

require_relative "stream_rule"
require_relative "validator"

module X
  module Streams
    # The rules of the filtered stream, read from what a caller gives and what the API returns
    #
    # A rule is given as a StreamRule, a Hash, a String, or, to delete it, an Integer or the X::MatchingRule of a post
    # of x-resources, and each of the rules methods of a streaming client reads it here into what the API takes.
    #
    # Internal to x-streams: StreamingClient reads the rules it adds and deletes with it.
    #
    # @api private
    module StreamRules
      extend self

      # The message of the error raised for something that is neither a rule nor the identifier of one
      NOT_A_RULE = "a rule is a StreamRule, a Hash holding an id or a value, an X::MatchingRule, the value it matches, " \
        "or its identifier, not %s"
      # The message of the error raised for something that is neither a rule to add nor the value one matches
      NOT_A_RULE_TO_ADD = "a rule to add is a StreamRule, a Hash holding a value, or the value it matches, not %s"
      # What the type of the problem of a rule the app already has ends in
      DUPLICATE_RULES = "/duplicate-rules"
      private_constant :NOT_A_RULE, :NOT_A_RULE_TO_ADD, :DUPLICATE_RULES

      # The rules to delete, named by identifier and by the value they match
      #
      # A list the API is given none of would delete every rule, so neither is sent unless it holds something. The API
      # takes an identifier as a String, as it sends one, so an Integer is sent as one, and each is read as strictly
      # as a StreamRule reads one, so that " 1_0 " is not sent for 10, nor -1 for a rule.
      #
      # @api private
      # @param ids [Array] the rules that hold an identifier
      # @param values [Array] the rules that hold a value and no identifier
      # @return [Hash{Symbol => Array}] the identifiers and values of the rules to delete
      # @raise [ArgumentError] if an identifier is neither an Integer that is not negative nor a String of digits
      def deletion(ids, values)
        {ids: ids.map { |rule| Validator.identifier!(identifier_of(rule)).to_s }, values: values.map { |rule| value_of(rule) }}.reject { |_, list| list.empty? }
      end

      # The rules given, which may be one rule rather than a list of them
      #
      # Only an Array is read as a list of rules, and anything else as one rule, since Array() would read a Hash as the
      # list of its pairs, and a Struct as the list of its members, so that a Struct of a value and a tag would add its
      # tag as a rule, and one of an identifier and a text delete the rule of that identifier. nil is no rules. A
      # StreamRule is read as the Hash of what it holds, which the rest read as they read any other.
      #
      # @api private
      # @param rules [Array, StreamRule, Hash, String, Integer, nil] the rules, or one rule
      # @return [Array] the rules
      def each_rule(rules)
        listed = rules.nil? ? [] : Array.try_convert(rules) || [rules] #: Array[untyped]
        listed.map { |rule| rule.is_a?(StreamRule) ? rule.to_h.compact : rule }
      end

      # The rules of a response, which holds none when it changed or matched none
      # @api private
      # @param body [Hash, nil] the parsed response body
      # @return [Array<StreamRule>] the rules, frozen
      def rules_of(body)
        rules = Array(body.to_h["data"]) #: Array[Hash[String, untyped]]
        rules.map { |rule| StreamRule.new(id: rule["id"], value: rule["value"], tag: rule["tag"]) }.freeze
      end

      # Check whether a problem is of a rule the app already has
      #
      # The API reports a rule it was asked to add that matches the value of a rule the app has as a DuplicateRule,
      # whose type ends in duplicate-rules. It is not a rule the API rejected, so add_rules raises nothing for it.
      #
      # @api private
      # @param problem [Problem] the problem the API reported
      # @return [Boolean] true if the problem is a DuplicateRule
      def duplicate?(problem) = problem.type.to_s.end_with?(DUPLICATE_RULES)

      # The token of the page of rules after a response, or nil for the last page
      #
      # An empty token names no page, and a token that fetched a page already would have the pages requested again for
      # good, and the API bills each request, so the page that names either is the last, as a page that names none is.
      #
      # @api private
      # @param body [Hash, nil] the parsed response body
      # @param spent [Array<String>] the tokens that fetched the pages before it
      # @return [String, nil] the token, or nil if the page is the last
      def next_token(body, spent)
        token = body.to_h.dig("meta", "next_token")
        token unless ["", *spent].include?(token)
      end

      # A rule to add, from the rule itself or the value it matches
      #
      # The API gives each rule it adds an identifier of its own, so one that a rule holds, as a rule that was read
      # does, is not sent.
      #
      # @api private
      # @param rule [Hash, String] the rule, or the value it matches
      # @return [Hash] the rule
      # @raise [ArgumentError] if the rule is neither a String nor a Hash that holds a value
      def rule_to_add(rule)
        value = String.try_convert(rule)
        return {value:} if value

        hash = Hash.try_convert(rule)
        return hash.except("id", :id) if hash && (hash["value"] || hash[:value])

        raise ArgumentError, format(NOT_A_RULE_TO_ADD, rule.inspect)
      end

      # The identifier of a rule, if it is one or holds one
      #
      # A String is the value a rule matches, as add_rules reads it, so an identifier is an Integer, held by a Hash,
      # or read from the id of an X::MatchingRule, which each post of x-resources names in matching_rules, and which holds
      # no value. Anything else with an id is not read for one, since a post, a user, or any other resource has an id
      # too, which would delete whichever rule shared it.
      #
      # @api private
      # @param rule [Hash, String, Integer, X::MatchingRule] the rule, the value it matches, or its identifier
      # @return [Object, nil] the identifier, or nil for a rule that holds none
      def identifier_of(rule)
        hash = Hash.try_convert(rule)
        return hash["id"] || hash[:id] if hash
        return rule if rule.instance_of?(Integer)

        rule.id if matching_rule?(rule)
      end

      # Check whether a rule is an X::MatchingRule
      #
      # x-streams does not depend on x-resources, which defines X::MatchingRule, so no rule is one until x-resources is
      # loaded.
      #
      # @api private
      # @param rule [Object] the rule
      # @return [Boolean, nil] true if x-resources is loaded and the rule is an X::MatchingRule
      def matching_rule?(rule) = defined?(X::MatchingRule) && rule.is_a?(X::MatchingRule) # steep:ignore UnknownConstant

      # The value a rule matches, which deletes a rule holding no identifier
      # @api private
      # @param rule [Hash, String] the rule, or the value it matches
      # @return [String] the value
      # @raise [ArgumentError] if the rule is neither a String nor a Hash that holds an identifier or a value
      def value_of(rule)
        value = String.try_convert(rule)
        return value if value

        hash = Hash.try_convert(rule) || {} #: Hash[untyped, untyped]
        hash["value"] || hash[:value] || raise(ArgumentError, format(NOT_A_RULE, rule.inspect))
      end
    end
    private_constant :StreamRules
  end
end
