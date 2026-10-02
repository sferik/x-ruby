# frozen_string_literal: true

require "x/core"

module X
  # A rule of the filtered stream: the value it matches posts against, the tag it is labelled with, and the
  # identifier the API gave it
  #
  # {StreamingClient#rules} and {StreamingClient#add_rules} return the rules the API holds, and
  # {StreamingClient#delete_rules} deletes one by its identifier, so a rule that was read deletes itself. A rule
  # built to be added has no identifier until the API gives it one, and is deleted by the value it matches.
  #
  # It is frozen, compares equal to a rule of the same identifier, value, and tag, and matches a pattern of them, as
  # in `rule in {value: /ruby/, tag: nil}`.
  #
  # @api public
  class StreamRule
    # The message of the error raised for a value or a tag that is not a String
    NOT_A_STRING = "%s must be a String, not %s"
    private_constant :NOT_A_STRING

    # The number of the format of the state Marshal writes, which every release of 1.x writes
    #
    # A later release of 1.x adds to the state only what an earlier one ignores, parts after those it reads and keys of a
    # Hash it does not read, so that the state one release of 1.x writes is read by every other, earlier or later.
    MARSHAL_FORMAT = 1
    private_constant :MARSHAL_FORMAT

    # The identifier the API gave the rule
    #
    # The API sends it as a String, and it is read as an Integer, as the identifier of a resource of the object layer
    # is.
    #
    # @api public
    # @return [Integer, nil] the identifier, or nil for a rule the API has not given one
    # @example Get the identifier
    #   rule.id # => 1165037377523306498
    attr_reader :id

    # The value the rule matches posts against
    # @api public
    # @return [String] the value, in the syntax of the filtered stream
    # @example Get the value
    #   rule.value # => "ruby -is:retweet"
    attr_reader :value

    # The tag the rule is labelled with, which each post it matches names
    # @api public
    # @return [String, nil] the tag, or nil for a rule without one
    # @example Get the tag
    #   rule.tag # => "ruby"
    attr_reader :tag

    # Initialize a rule
    #
    # @api public
    # @param value [String] the value the rule matches posts against
    # @param tag [String, nil] the tag the rule is labelled with, or nil for none
    # @param id [Integer, String, nil] the identifier the API gave the rule, as an Integer or as the String the API
    #   sends, or nil for a rule it has not given one
    # @return [StreamRule] the frozen rule
    # @raise [ArgumentError] if the value is not a String, the tag is neither a String nor nil, or the identifier
    #   names no number
    # @example Build a rule to add
    #   X::StreamRule.new(value: "ruby -is:retweet", tag: "ruby")
    def initialize(value:, tag: nil, id: nil)
      @id = Integer(id.to_s, 10) unless id.nil?
      @value = string!(:value, value)
      @tag = string!(:tag, tag) unless tag.nil?
      freeze
    end

    # The rule as a Hash
    #
    # @api public
    # @return [Hash{Symbol => Integer, String, nil}] the identifier, value, and tag
    # @example Store a rule
    #   store.save(**rule.to_h)
    def to_h = {id:, value:, tag:}

    # The identifier, value, and tag of the rule, which a pattern matches against
    #
    # @api public
    # @param _keys [Array<Symbol>, nil] the keys the pattern names
    # @return [Hash{Symbol => Integer, String, nil}] the identifier, value, and tag
    # @example Match the rules without a tag
    #   streaming_client.rules.select { |rule| rule in {tag: nil} }
    def deconstruct_keys(_keys) = to_h

    # Check whether another rule is the same rule
    #
    # @api public
    # @param other [Object] the other rule
    # @return [Boolean] true if the other rule is a StreamRule of the same identifier, value, and tag
    # @example Check whether a rule was read before
    #   streaming_client.rules.include?(rule)
    def ==(other) = other.instance_of?(self.class) && to_h.eql?(other.to_h)
    alias_method :eql?, :==

    # The hash of the rule, which equal rules share
    #
    # @api public
    # @return [Integer] the hash
    # @example Count the distinct rules
    #   rules.uniq.size
    def hash = [self.class, to_h].hash

    # Summarize the rule for the console
    #
    # @api public
    # @return [String] the class name, identifier, value, and tag
    # @example Inspect a rule
    #   rule.inspect # => #<X::StreamRule id=1165037377523306498 value="ruby -is:retweet" tag="ruby">
    def inspect = "#<#{self.class} id=#{id.inspect} value=#{value.inspect} tag=#{tag.inspect}>"

    # The state Marshal writes
    #
    # What is written is plain data, led by the number of its format, so that a rule written by one release of 1.x is
    # read by a later one: its identifier, value, and tag, as to_h gives them.
    #
    # @api public
    # @return [Array(Integer, Hash{Symbol => Integer, String, nil})] the number of the format, then the rule as a Hash
    # @example Cache the rules of the filtered stream
    #   Rails.cache.write("rules", streaming_client.rules)
    def marshal_dump = [MARSHAL_FORMAT, to_h]

    # Restore a rule Marshal read, built as the constructor builds it, frozen
    #
    # @api public
    # @param state [Array] the state Marshal wrote
    # @return [void]
    # @raise [UnsupportedMarshalFormat] if the state is of a format this release does not read
    # @example Read cached rules
    #   Marshal.load(Marshal.dump(rule)).value
    def marshal_load(state)
      format, rule = state #: [Integer, {id: Integer?, value: String, tag: String?}]
      raise UnsupportedMarshalFormat, "#{self.class} reads format #{MARSHAL_FORMAT} of Marshal, not #{format.inspect}" unless MARSHAL_FORMAT.eql?(format)

      initialize(**rule.slice(:id, :value, :tag)) # steep:ignore InsufficientKeywordArguments
    end

    # Write the state Marshal writes as YAML
    #
    # YAML would write the instance variables of the rule, and read them back into a rule that is not frozen, so
    # it says how it is written: the number of its format, then each of its parts, under the name to_h gives it.
    #
    # @api public
    # @param coder [Psych::Coder] the coder YAML writes the rule with
    # @return [void]
    # @example Write a rule as YAML
    #   YAML.dump(rule)
    def encode_with(coder)
      coder["format"] = MARSHAL_FORMAT
      to_h.each { |key, value| coder[key.to_s] = value }
    end

    # Restore a rule YAML read, frozen, as Marshal restores one
    #
    # @api public
    # @param coder [Psych::Coder] the coder YAML read the rule with
    # @return [void]
    # @raise [UnsupportedMarshalFormat] if the state is of a format this release does not read
    # @example Read a rule written as YAML
    #   YAML.unsafe_load(YAML.dump(rule)).value
    def init_with(coder) = marshal_load([coder["format"], coder.map.transform_keys(&:to_sym)])

    private

    # A frozen copy of a String a rule holds
    # @api private
    # @param name [Symbol] the name of the attribute, which the error names
    # @param string [Object] the value of the attribute
    # @return [String] the frozen copy
    # @raise [ArgumentError] if the value is not a String
    def string!(name, string)
      (String.try_convert(string) || raise(ArgumentError, format(NOT_A_STRING, name, string.inspect))).dup.freeze
    end
  end
end
