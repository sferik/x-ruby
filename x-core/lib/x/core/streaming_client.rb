# frozen_string_literal: true

require "uri"
require_relative "connection"
require_relative "credential_holder"
require_relative "errors/rules_rejected"
require_relative "origin"
require_relative "problem"
require_relative "proxy_setting"
require_relative "reconnect_handler"
require_relative "request_builder"
require_relative "request_encoding"
require_relative "response"
require_relative "response_parser"
require_relative "setting_validator"
require_relative "stream_parser"
require_relative "stream_rule"
require_relative "stream_rules"

module X
  module Core
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
    # A stream of another origin than the base URL of the client carries none of its credentials, as a request to
    # one carries none of them; see {Core::Origin}.
    #
    # A streaming client keeps the settings it was built with for as long as it lives, as a client does, so a stream
    # that runs for hours never reads a setting another thread is halfway through changing. {Client#streaming} builds
    # one whose read_timeout or max_reconnects differ, and it takes the rest of its settings from the client it is
    # built from, so a stream that connects differently is opened from a copy of that client:
    # client.with(open_timeout: 2).streaming.
    #
    # @api public
    class ::X::StreamingClient
      include CredentialHolder
      include ProxySetting
      include RequestEncoding

      # Default timeout for reading from a stream in seconds, half again the 20-second interval of the keep-alive X sends
      DEFAULT_READ_TIMEOUT = 30 # seconds
      # Default maximum number of times in a row to reconnect a stream that drops without delivering an object
      DEFAULT_MAX_RECONNECTS = ReconnectHandler::DEFAULT_MAX_RECONNECTS
      # The message of the error raised for a stream without a block to deliver its objects to
      NO_BLOCK_MESSAGE = "stream takes a block, which receives each object the stream delivers"
      private_constant :NO_BLOCK_MESSAGE
      # The endpoint that reads and changes the rules the filtered stream matches posts against
      RULES_ENDPOINT = "tweets/search/stream/rules"
      private_constant :RULES_ENDPOINT
      # The classes the rules endpoints parse into, whatever parsing classes the client defaults to
      JSON_CLASSES = {array_class: Array, object_class: Hash}.freeze
      private_constant :JSON_CLASSES

      # The client the stream authenticates and parses with
      # @api public
      # @return [Client] the client
      # @example Read the base URL of a stream
      #   streaming_client.client.base_url
      attr_reader :client

      # Initialize a client for the streaming endpoints
      #
      # @api public
      # @param client [Client] the client whose credentials, base URL, and settings the stream uses
      # @param read_timeout [Integer, Float, nil] the timeout for reading from a stream in seconds, or nil for none,
      #   which leaves a stream X stopped sending to open until the operating system gives up on its connection
      # @param max_reconnects [Integer, Float] the maximum number of times in a row to reconnect a stream that drops
      #   without delivering an object, or Float::INFINITY, the default, for no limit
      # @return [StreamingClient] a new instance
      # @raise [ArgumentError] if the read timeout is neither a finite number of seconds of at least 0 nor nil, or the
      #   maximum number of reconnects is neither a count nor Float::INFINITY
      # @example Create a streaming client
      #   streaming_client = X::StreamingClient.new(client, max_reconnects: 5)
      def initialize(client, read_timeout: DEFAULT_READ_TIMEOUT, max_reconnects: DEFAULT_MAX_RECONNECTS)
        @client = client
        @proxy_url = client.__send__(:proxy_url)
        @connection = Connection.new(open_timeout: client.open_timeout, read_timeout:, write_timeout: client.write_timeout,
          debug_output: client.debug_output, proxy_url:)
        @reconnect_handler = ReconnectHandler.new(max_reconnects:, max_rate_limit_wait: client.max_rate_limit_wait)
        @request_builder = RequestBuilder.new
        @response_parser = ResponseParser.new
        @stream_parser = StreamParser.new
      end

      # The timeout for opening a stream's connection, in seconds, which is the client's
      # @api public
      # @return [Integer, Float, nil] the timeout, or nil for none
      # @example Get the open timeout
      #   streaming_client.open_timeout # => 10
      def open_timeout = @connection.open_timeout

      # The timeout for reading from a stream, in seconds
      # @api public
      # @return [Integer, Float, nil] the timeout, or nil for none
      # @example Get the read timeout
      #   streaming_client.read_timeout # => 30
      def read_timeout = @connection.read_timeout

      # The timeout for writing a stream's request, in seconds, which is the client's
      # @api public
      # @return [Integer, Float, nil] the timeout, or nil for none
      # @example Get the write timeout
      #   streaming_client.write_timeout # => 60
      def write_timeout = @connection.write_timeout

      # The IO debug output is written to, which is the client's
      # @api public
      # @return [IO, #<<, nil] the IO, or anything else that takes a String with <<, or nil for none
      # @example Get the debug output
      #   streaming_client.debug_output
      def debug_output = @connection.debug_output

      # The maximum number of times in a row to reconnect a stream
      #
      # A stream is reconnected when it drops without delivering an object.
      #
      # @api public
      # @return [Integer, Float] the maximum, or Float::INFINITY for no limit
      # @example Get the maximum number of reconnects
      #   streaming_client.max_reconnects
      def max_reconnects = @reconnect_handler.max_reconnects

      # Summarize the streaming client for the console without revealing credentials
      #
      # @api public
      # @return [String] the class name and the client it streams with
      # @example Inspect a streaming client
      #   streaming_client.inspect # => #<X::StreamingClient client=#<X::Client ...>>
      def inspect = "#<#{self.class} client=#{client.inspect}>"

      # Stream data from the X API
      #
      # The stream endpoints take app-only authentication, so a client that authenticates as a user streams with the
      # bearer token its app_only client holds. A client that authenticates with OAuth 2.0 as a user and holds neither
      # the app's bearer token nor its API key and secret raises UnsupportedOperation before it connects, rather than
      # open a stream X would refuse with 403 Forbidden. A bearer token X rejects with 401 Unauthorized, as it does one
      # that was invalidated, is fetched again with the API key and secret the app_only client holds, as it is for a
      # request, and the stream is opened once more with it. A stream that drops, or that X disconnects with an
      # operational-disconnect, reconnects, backing off as X recommends, up to max_reconnects times in a row. The API bills
      # each object a stream delivers, so the client's on_response receives each one, as well as a failed response.
      # An error on_response or the object_class raises stops the stream, and reaches the caller as it was raised, even
      # an error of the X API, such as the X::ServiceUnavailable of a request on_response made, which a stream that
      # dropped reconnects after.
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
      # @param object_class [Class, #from_response] the class for parsing JSON objects, or one that responds to
      #   from_response and builds the result from each whole object the stream delivers; see {Client}
      # @yield [Hash, Array] each parsed JSON object from the stream
      # @return [Object, nil] what the block broke with, or nil once the stream ends with no reconnects left
      # @raise [ArgumentError] if no block is given, or the endpoint is not a valid URL, or does not resolve to an http or
      #   https URL, before the stream is opened
      # @raise [ArgumentError] if array_class is not a Class, or object_class is neither a Class nor responds to
      #   from_response, before the stream is opened
      # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user and holds no credentials of
      #   the app, before the stream is opened
      # @raise [HTTPError] if the response is not successful and the stream may not reconnect
      # @raise [StreamError] if a line holds errors and no data, which the stream reconnects after only when each is an
      #   operational-disconnect, and then raises once it has no reconnects left
      # @example Stream filtered posts
      #   streaming_client.stream("tweets/search/stream") { |post| puts post }
      # @example Stop the stream from its block
      #   first = streaming_client.stream("tweets/search/stream") { |post| break post }
      def stream(endpoint, params: nil, headers: {}, array_class: client.default_array_class,
        object_class: client.default_object_class, &block)
        raise ArgumentError, NO_BLOCK_MESSAGE if block.nil?

        SettingValidator.parsing_classes!(array_class:, object_class:)
        uri = uri_for(client.base_url, endpoint, params)
        @reconnect_handler.handle(block) do |deliver|
          app_client.__send__(:refreshing_rejected_token) { open_stream(uri, headers, array_class:, object_class:, &deliver) }
        end
      end

      # The rules the filtered stream matches posts against
      #
      # The rules of an app are read, added, and deleted through a streaming client because they belong to the stream:
      # they are what the filtered stream delivers, and they take the app-only authentication a stream takes. The API
      # returns the rules a page at a time, and every page is read, so the rules are all of them.
      #
      # @api public
      # @param params [Hash, nil] query parameters appended to the endpoint of each page
      # @return [Array<StreamRule>] the rules, frozen, empty if the app has none
      # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user and holds no credentials of
      #   the app
      # @raise [HTTPError] if the API refuses the request
      # @example Print the rules of the app
      #   streaming_client.rules.each { |rule| puts "#{rule.tag}: #{rule.value}" }
      # @example Read two rules by identifier
      #   streaming_client.rules(params: {ids: "1,2"})
      def rules(params: nil)
        body = app_client.get(RULES_ENDPOINT, params:, **JSON_CLASSES)
        token = body.to_h.dig("meta", "next_token")
        (StreamRules.rules_of(body) + (token ? rules(params: params.to_h.merge(pagination_token: token)) : [])).freeze
      end

      # Add rules for the filtered stream to match posts against
      #
      # A rule is a StreamRule, or a Hash of the value it matches and the tag it is labelled with, or a String, which is
      # the value of a rule without a tag. A StreamRule is added by its value and tag, so the rules of one app, as
      # {#rules} returns them, add themselves to another. No rules add none, and send no request. Anything else
      # raises before a request, as it does for delete_rules.
      #
      # The API adds the rules it can and reports the rest, such as a rule the app already has, as errors of a
      # response that otherwise succeeds. The rules that were added are returned, and each rule that was not is
      # yielded as the Problem the API reported, as a finder of x-objects yields the problems of a lookup. Without a
      # block, a rule that was not added raises RulesRejected, which holds the rules that were, so that neither a
      # rule the app already has nor one a dry run found invalid is passed over in silence.
      #
      # @api public
      # @param rules [Array<StreamRule, Hash, String>, StreamRule, Hash, String] the rules to add
      # @param dry_run [Boolean] true to have the API check the rules and add none of them
      # @yieldparam problem [Problem] each rule the API did not add, and why, such as a DuplicateRule
      # @return [Array<StreamRule>] the rules that were added, frozen, each holding the id the API gave it, empty if
      #   none were given
      # @raise [ArgumentError] if something is neither a StreamRule, a Hash that holds a value, nor a String
      # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user and holds no credentials of
      #   the app
      # @raise [HTTPError] if the API refuses the request, which adds none of the rules
      # @raise [RulesRejected] if the API did not add a rule, and no block was given for it
      # @example Add a rule with a tag
      #   rule = streaming_client.add_rules(X::StreamRule.new(value: "ruby -is:retweet", tag: "ruby")).first
      #   rule.id # => 1165037377523306498
      # @example Check rules without adding them
      #   streaming_client.add_rules(["ruby", "crystal"], dry_run: true)
      # @example Report the rules that were not added
      #   streaming_client.add_rules(%w[ruby crystal]) { |problem| warn "#{problem.value}: #{problem.title}" }
      def add_rules(rules, dry_run: false, &)
        rules = StreamRules.each_rule(rules)
        body = change_rules({add: rules.map { |rule| StreamRules.rule_to_add(rule) }}, dry_run:) unless rules.empty?
        reporting(body, StreamRules.rules_of(body), &)
      end

      # Delete rules of the filtered stream
      #
      # A rule is deleted by its identifier, or by the value it matches: a StreamRule the API returned, a Hash that holds
      # an id, or an Integer is deleted by identifier, so what {#rules} returned deletes itself, and a StreamRule or
      # a Hash that holds a value and no identifier, or a String, is deleted by value, so what add_rules was
      # given deletes what it added. No rules delete none, and send no request, since the API refuses a deletion that
      # names no rule.
      #
      # The API deletes the rules it can and reports the rest, such as a rule the app does not have, as errors of a
      # response that otherwise succeeds. The number of rules that were deleted is returned, and each problem the API
      # reported is yielded, as add_rules yields the rules it did not add, or, without a block, raises RulesRejected,
      # which holds the number.
      #
      # @api public
      # @param rules [Array<StreamRule, Hash, String, Integer>, StreamRule, Hash, String, Integer] the rules to delete,
      #   the values they match, or their identifiers
      # @param dry_run [Boolean] true to have the API check the rules and delete none of them
      # @yieldparam problem [Problem] each problem the API reported of the rules it did not delete
      # @return [Integer] the number of rules deleted, or that a dry run would delete, 0 if none were given
      # @raise [ArgumentError] if something is neither a rule nor the identifier of one
      # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user and holds no credentials of
      #   the app
      # @raise [HTTPError] if the API refuses the request
      # @raise [RulesRejected] if the API reported a problem of a rule, and no block was given for it
      # @example Delete every rule
      #   streaming_client.delete_rules(streaming_client.rules)
      # @example Delete the rules that match two values
      #   streaming_client.delete_rules(["ruby", "crystal"])
      # @example Delete a rule by the identifier the API gave it
      #   streaming_client.delete_rules(1165037377523306498)
      # @example Report the rules that were not deleted
      #   streaming_client.delete_rules([1, 2]) { |problem| warn problem.detail }
      def delete_rules(rules, dry_run: false, &)
        rules = StreamRules.each_rule(rules)
        return 0 if rules.empty?

        ids, values = rules.partition { |rule| StreamRules.identifier_of(rule) }
        body = change_rules({delete: StreamRules.deletion(ids, values)}, dry_run:)
        reporting(body, body.to_h.dig("meta", "summary", "deleted").to_i, &)
      end

      private

      # Send a change of the rules, as the app
      # @api private
      # @param body [Hash] the rules to add or delete
      # @param dry_run [Boolean] true to have the API check the rules and change none of them
      # @return [Hash, nil] the parsed response body
      def change_rules(body, dry_run:) = app_client.post(RULES_ENDPOINT, body, params: {dry_run: (true if dry_run)}, **JSON_CLASSES)

      # Yield each problem of a change of the rules, or raise for them without a block
      #
      # @api private
      # @param body [Hash, nil] the parsed response body, or nil when no rules were given
      # @param result [Array<StreamRule>, Integer] what the change returns
      # @yieldparam problem [Problem] each problem the API reported
      # @return [Array<StreamRule>, Integer] the result
      # @raise [RulesRejected] if the API reported a problem and no block was given
      def reporting(body, result)
        problems = Problem.all_from(body)
        if block_given?
          problems.each { |problem| yield problem }
        elsif problems.any?
          raise RulesRejected.new(problems, result:)
        end
        result
      end

      # Open a stream once, and deliver each object it sends until it ends
      # @api private
      # @param uri [URI::Generic] the URI of the stream
      # @param headers [Hash] the headers of the stream, beside those of the client
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class, #from_response] the class for parsing JSON objects
      # @yield [Hash, Array] each parsed JSON object from the stream
      # @return [void]
      def open_stream(uri, headers, array_class:, object_class:, &)
        request = request_for(uri, headers)
        @connection.perform_stream(request:) do |response|
          @stream_parser.process(response:, response_parser: @response_parser, array_class:, object_class:, client:,
            on_body: ->(body = nil) { report(uri, response, body) }, request:, &)
        end
      end

      # The client the rules are read and changed with, which authenticates as the app
      # @api private
      # @return [Client] the app-only client
      def app_client = client.app_only

      # Build a request that authenticates as the app
      #
      # The client's headers are sent with a stream as they are with a request, and a header of the same name passed
      # to the stream is sent in place of one of them. A stream of another origin than the base URL carries none of
      # the client's credentials, as a request to one carries none of them.
      #
      # @api private
      # @param uri [URI::Generic] the URI of the stream
      # @param headers [Hash] additional headers for the request
      # @return [Net::HTTPRequest] the request
      def request_for(uri, headers)
        authenticator, headers = Origin.credentials_for(from: URI(client.base_url), to: uri,
          authenticator: app_client.authenticator, headers: RequestBuilder.merge_headers(client.headers, headers))
        @request_builder.build(http_method: :get, uri:, headers:, authenticator:)
      end

      # Pass a response, or one object of a stream, to the client's on_response
      # @api private
      # @param uri [URI::Generic] the URI of the stream
      # @param response [Net::HTTPResponse] the HTTP response
      # @param body [String, nil] the object the stream delivered, or nil for the whole body
      # @return [void]
      def report(uri, response, body) = client.on_response&.call(Response.new(:get, uri, response, body:))
    end
  end
end
