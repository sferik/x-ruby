# frozen_string_literal: true

require "forwardable"
require "uri"
require_relative "connection"
require_relative "reconnect_handler"
require_relative "request_builder"
require_relative "request_encoding"
require_relative "response"
require_relative "response_parser"
require_relative "stream_parser"

module X
  # A client for the streaming endpoints, which hold a connection open rather than answer a request
  #
  # A stream reads until it is interrupted, so it reads with a short timeout and reconnects when it drops. The
  # streaming endpoints require app-only authentication, so it streams with the bearer token of a client that has
  # one, or fetches one with the API key and secret of a client that signs with OAuth 1.0a. It takes its credentials,
  # base URL, parsing classes, and on_response hook from the client it was built from, and keeps the rest of its
  # settings itself.
  #
  # Each stream opens a connection of its own and closes it when it ends, rather than keep one open for the request
  # that follows, as a client does between requests. So a streaming client has neither the keep_alive_timeout of a
  # client, which says how long a connection is kept open, nor its close, which closes the connections it kept: a
  # streaming client keeps none between streams, and a stream is stopped by raising from the block that reads it.
  #
  # A streaming client keeps the settings it was built with for as long as it lives, as a client does, so a stream
  # that runs for hours never reads a setting another thread is halfway through changing. {Client#streaming} builds
  # one whose read_timeout or max_reconnects differ, and it takes the rest of its settings from the client it is
  # built from, so a stream that connects differently is opened from a copy of that client:
  # client.with(open_timeout: 2).streaming.
  #
  # @api public
  class StreamingClient
    extend Forwardable
    include Core::RequestEncoding

    # Default timeout for reading from a stream in seconds, half again the 20-second interval of the keep-alive X sends
    DEFAULT_READ_TIMEOUT = 30 # seconds
    # Default maximum number of times in a row to reconnect a stream that drops without delivering an object
    DEFAULT_MAX_RECONNECTS = Core::ReconnectHandler::DEFAULT_MAX_RECONNECTS
    # The message of the error raised for a stream without a block to deliver its objects to
    NO_BLOCK_MESSAGE = "stream takes a block, which receives each object the stream delivers"
    private_constant :NO_BLOCK_MESSAGE
    # The endpoint that reads and changes the rules the filtered stream matches posts against
    RULES_ENDPOINT = "tweets/search/stream/rules"
    private_constant :RULES_ENDPOINT
    # The message of the error raised for something that is neither a rule nor the identifier of one
    NOT_A_RULE = "a rule is a Hash holding an id or a value, or the identifier of one, not %s"
    private_constant :NOT_A_RULE
    # The classes the rules endpoints parse into, whatever parsing classes the client defaults to
    JSON_CLASSES = {array_class: Array, object_class: Hash}.freeze
    private_constant :JSON_CLASSES

    # The client the stream authenticates and parses with
    # @api public
    # @return [Client] the client
    # @example Read the base URL of a stream
    #   streaming_client.client.base_url
    attr_reader :client

    def_delegators :@connection, :open_timeout, :read_timeout, :write_timeout, :proxy_url, :debug_output
    def_delegator :@reconnect_handler, :max_reconnects

    # Initialize a client for the streaming endpoints
    #
    # @api public
    # @param client [Client] the client whose credentials, base URL, and settings the stream uses
    # @param read_timeout [Integer, Float] the timeout for reading from a stream in seconds
    # @param max_reconnects [Integer, Float] the maximum number of times in a row to reconnect a stream that drops
    #   without delivering an object, or Float::INFINITY, the default, for no limit
    # @return [StreamingClient] a new instance
    # @example Create a streaming client
    #   streaming_client = X::StreamingClient.new(client, max_reconnects: 5)
    def initialize(client, read_timeout: DEFAULT_READ_TIMEOUT, max_reconnects: DEFAULT_MAX_RECONNECTS)
      @client = client
      @connection = Connection.new(open_timeout: client.open_timeout, read_timeout:, write_timeout: client.write_timeout,
        debug_output: client.debug_output, proxy_url: client.proxy_url)
      @reconnect_handler = Core::ReconnectHandler.new(max_reconnects:)
      @request_builder = Core::RequestBuilder.new
      @response_parser = Core::ResponseParser.new
      @stream_parser = Core::StreamParser.new
    end

    # Summarize the streaming client for the console without revealing credentials
    #
    # @api public
    # @return [String] the class name and the client it streams with
    # @example Inspect a streaming client
    #   streaming_client.inspect # => #<X::StreamingClient client=#<X::Client ...>>
    def inspect
      "#<#{self.class} client=#{client.inspect}>"
    end

    # Stream data from the X API
    #
    # The stream endpoints take app-only authentication, so a client that signs with OAuth 1.0a streams with the
    # bearer token its app_only client holds. A client that authenticates with OAuth 2.0 as a user holds no app-only
    # credentials, so it raises UnsupportedOperation before it connects, rather than open a stream X would refuse with 403
    # Forbidden; stream with a client built from the app's bearer token, or its API key and secret, instead. A
    # stream that drops reconnects, backing off as X recommends, up to max_reconnects times in a row. The API bills
    # each object a stream delivers, so the client's on_response receives each one, as well as a failed response.
    #
    # A stream runs until its block stops it: break out of the block to stop the stream and return a value, throw to
    # unwind to a catch further out, or raise, which stops the stream even where a drop would have reconnected, and
    # reaches the caller unchanged, a StopIteration included.
    #
    # @api public
    # @param endpoint [String] the streaming API endpoint, relative to the base URL with or without a leading slash
    # @param params [Hash, nil] query parameters appended to the endpoint
    # @param headers [Hash] additional headers for the request, sent in place of the client's headers of the same
    #   name, which are themselves sent in place of the defaults of the gem
    # @param array_class [Class] the class for parsing JSON arrays
    # @param object_class [Class] the class for parsing JSON objects, or one that responds to from_response
    #   and builds objects from each whole object the stream delivers, which it receives with the client
    # @yield [Hash, Array] each parsed JSON object from the stream
    # @return [nil] once the stream ends with no reconnects left, or what the block broke with
    # @raise [ArgumentError] if no block is given
    # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user, before the stream is opened
    # @raise [HTTPError] if the response is not successful and the stream may not reconnect
    # @example Stream filtered posts
    #   streaming_client.stream("tweets/search/stream") { |post| puts post }
    # @example Stop the stream from its block
    #   first = streaming_client.stream("tweets/search/stream") { |post| break post }
    def stream(endpoint, params: nil, headers: {}, array_class: client.default_array_class,
      object_class: client.default_object_class, &block)
      raise ArgumentError, NO_BLOCK_MESSAGE if block.nil?

      uri = URI.join(client.base_url, endpoint_with(endpoint, params))
      @reconnect_handler.handle(block) do |deliver|
        @connection.perform_stream(request: request_for(uri, headers)) do |response|
          @stream_parser.process(response:, response_parser: @response_parser, array_class:, object_class:, client:,
            on_body: ->(body = nil) { report(uri, response, body) }, &deliver)
        end
      end
    end

    # The rules the filtered stream matches posts against
    #
    # The rules of an app are read, added, and deleted through a streaming client because they belong to the stream:
    # they are what the filtered stream delivers, and they take the app-only authentication a stream takes.
    #
    # @api public
    # @param params [Hash, nil] query parameters appended to the endpoint
    # @return [Array<Hash>] the rules, each holding its id, value, and tag, empty if the app has none
    # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user
    # @raise [HTTPError] if the API refuses the request
    # @example Print the rules of the app
    #   streaming_client.stream_rules.each { |rule| puts "#{rule["tag"]}: #{rule["value"]}" }
    def stream_rules(**params)
      rules_of(app_client.get(RULES_ENDPOINT, params:, **JSON_CLASSES))
    end

    # Add rules for the filtered stream to match posts against
    #
    # A rule is a Hash of the value it matches and the tag it is labelled with, or a String, which is the value of a
    # rule without a tag.
    #
    # @api public
    # @param rules [Array<Hash, String>, Hash, String] the rules to add
    # @param dry_run [Boolean] true to have the API check the rules and add none of them
    # @return [Array<Hash>] the rules that were added, each holding the id the API gave it
    # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user
    # @raise [HTTPError] if the API refuses a rule, which adds none of them
    # @example Add a rule with a tag
    #   streaming_client.add_stream_rules({value: "ruby -is:retweet", tag: "ruby"})
    # @example Check rules without adding them
    #   streaming_client.add_stream_rules(["ruby", "crystal"], dry_run: true)
    def add_stream_rules(rules, dry_run: false)
      rules_of(change_rules({add: each_rule(rules).map { |rule| rule_to_add(rule) }}, dry_run:))
    end

    # Delete rules of the filtered stream
    #
    # A rule is deleted by its identifier, or by the value it matches: a rule the API returned, or the identifier of
    # one, is deleted by identifier, and a Hash that holds a value and no identifier is deleted by value, so what
    # add_stream_rules was given deletes what it added.
    #
    # @api public
    # @param rules [Array<Hash, String, Integer>, Hash, String, Integer] the rules to delete, or their identifiers
    # @param dry_run [Boolean] true to have the API check the rules and delete none of them
    # @return [Integer] the number of rules deleted, or that a dry run would delete
    # @raise [ArgumentError] if something is neither a rule nor the identifier of one
    # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user
    # @raise [HTTPError] if the API refuses the request
    # @example Delete every rule
    #   streaming_client.delete_stream_rules(streaming_client.stream_rules)
    # @example Delete the rules that match two values
    #   streaming_client.delete_stream_rules([{value: "ruby"}, {value: "crystal"}])
    def delete_stream_rules(rules, dry_run: false)
      ids, values = each_rule(rules).partition { |rule| identifier_of(rule) }
      change_rules({delete: deletion(ids, values)}, dry_run:).to_h.dig("meta", "summary", "deleted").to_i
    end

    private

    # The rules to delete, named by identifier and by the value they match
    #
    # A list the API is given none of would delete every rule, so neither is sent unless it holds something.
    #
    # @api private
    # @param ids [Array] the rules that hold an identifier
    # @param values [Array] the rules that hold a value and no identifier
    # @return [Hash{Symbol => Array}] the identifiers and values of the rules to delete
    def deletion(ids, values)
      deleted = {} #: Hash[Symbol, Array[untyped]]
      deleted[:ids] = ids.map { |rule| identifier_of(rule) } unless ids.empty?
      deleted[:values] = values.map { |rule| value_of(rule) } unless values.empty?
      deleted
    end

    # Send a change of the rules, as the app
    # @api private
    # @param body [Hash] the rules to add or delete
    # @param dry_run [Boolean] true to have the API check the rules and change none of them
    # @return [Hash, nil] the parsed response body
    def change_rules(body, dry_run:)
      app_client.post(RULES_ENDPOINT, body, params: {dry_run: (true if dry_run)}, **JSON_CLASSES)
    end

    # The rules given, which may be one rule rather than a list of them
    #
    # Array() would read a Hash as the list of its pairs, so a single rule given as a Hash is wrapped instead.
    #
    # @api private
    # @param rules [Array, Hash, String, Integer] the rules, or one rule
    # @return [Array] the rules
    def each_rule(rules) = Hash.try_convert(rules) ? [rules] : Array(rules)

    # The rules of a response, which holds none when it changed or matched none
    # @api private
    # @param body [Hash, nil] the parsed response body
    # @return [Array<Hash>] the rules
    def rules_of(body) = Array(body.to_h["data"])

    # A rule to add, from the rule itself or the value it matches
    # @api private
    # @param rule [Hash, String] the rule, or the value it matches
    # @return [Hash] the rule
    def rule_to_add(rule) = Hash.try_convert(rule) || {value: rule}

    # The identifier of a rule, if it is one or holds one
    # @api private
    # @param rule [Hash, String, Integer] the rule, or its identifier
    # @return [String, Integer, nil] the identifier, or nil for a rule that holds none
    def identifier_of(rule)
      hash = Hash.try_convert(rule)
      return hash["id"] || hash[:id] if hash

      rule #: String | Integer
    end

    # The value a rule matches, which deletes a rule holding no identifier
    # @api private
    # @param rule [Hash] the rule
    # @return [String] the value
    # @raise [ArgumentError] if the rule holds neither an identifier nor a value
    def value_of(rule)
      hash = rule #: Hash[untyped, untyped]
      hash["value"] || hash[:value] || raise(ArgumentError, format(NOT_A_RULE, rule))
    end

    # The client the rules are read and changed with, which authenticates as the app
    # @api private
    # @return [Client] the app-only client
    def app_client = client.app_only

    # Build a request that authenticates as the app
    #
    # The client's headers are sent with a stream as they are with a request, and a header of the same name passed
    # to the stream is sent in place of one of them.
    #
    # @api private
    # @param uri [URI::Generic] the URI of the stream
    # @param headers [Hash] additional headers for the request
    # @return [Net::HTTPRequest] the request
    def request_for(uri, headers)
      @request_builder.build(http_method: :get, uri:, headers: client.headers.merge(headers), authenticator: client.app_only.authenticator)
    end

    # Pass a response, or one object of a stream, to the client's on_response
    # @api private
    # @param uri [URI::Generic] the URI of the stream
    # @param response [Net::HTTPResponse] the HTTP response
    # @param body [String, nil] the object the stream delivered, or nil for the whole body
    # @return [void]
    def report(uri, response, body)
      client.on_response&.call(Response.new(:get, uri, response, body:))
    end
  end
end
