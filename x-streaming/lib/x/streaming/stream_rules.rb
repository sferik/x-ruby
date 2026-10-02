# frozen_string_literal: true

require_relative "stream_rule"
require_relative "validator"

module X
  module Streaming
    # The rules of the filtered stream, read from what a caller gives and what the API returns
    #
    # A rule is given as a StreamRule, a Hash, a String, or, to delete it, an Integer, and each of the rules
    # methods of a streaming client reads it here into what the API takes.
    #
    # Internal to x-streaming: StreamingClient reads the rules it adds and deletes with it.
    #
    # @api private
    module StreamRules
      extend self

      # The message of the error raised for something that is neither a rule nor the identifier of one
      NOT_A_RULE = "a rule is a StreamRule, a Hash holding an id or a value, the value it matches, or its identifier, not %s"
      # The message of the error raised for something that is neither a rule to add nor the value one matches
      NOT_A_RULE_TO_ADD = "a rule to add is a StreamRule, a Hash holding a value, or the value it matches, not %s"
      private_constant :NOT_A_RULE, :NOT_A_RULE_TO_ADD

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
      # Array() would read a Hash as the list of its pairs, so a single rule given as a Hash is wrapped instead. A
      # StreamRule is read as the Hash of what it holds, which the rest read as they read any other.
      #
      # @api private
      # @param rules [Array, StreamRule, Hash, String, Integer] the rules, or one rule
      # @return [Array] the rules
      def each_rule(rules)
        (Hash.try_convert(rules) ? [rules] : Array(rules)).map { |rule| rule.is_a?(StreamRule) ? rule.to_h.compact : rule }
      end

      # The rules of a response, which holds none when it changed or matched none
      # @api private
      # @param body [Hash, nil] the parsed response body
      # @return [Array<StreamRule>] the rules, frozen
      def rules_of(body)
        rules = Array(body.to_h["data"]) #: Array[Hash[String, untyped]]
        rules.map { |rule| StreamRule.new(id: rule["id"], value: rule["value"], tag: rule["tag"]) }.freeze
      end

      # The token of the page of rules after a response, or nil for the last page
      #
      # An empty token names no page, and a token that fetched a page already would have the pages requested again for
      # good, and the API bill each request, so the page that names either is the last, as a page that names none is.
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
      # A String is the value a rule matches, as add_rules reads it, so an identifier is an Integer or held by a
      # Hash.
      #
      # @api private
      # @param rule [Hash, String, Integer] the rule, the value it matches, or its identifier
      # @return [String, Integer, nil] the identifier, or nil for a rule that holds none
      def identifier_of(rule)
        hash = Hash.try_convert(rule)
        return hash["id"] || hash[:id] if hash

        rule if rule.instance_of?(Integer)
      end

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
