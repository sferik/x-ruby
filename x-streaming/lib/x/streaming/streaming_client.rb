# frozen_string_literal: true

require "x/core"
require_relative "callback_error"
require_relative "reconnect_handler"
require_relative "rules_rejected"
require_relative "stream_parser"
require_relative "stream_rule"
require_relative "stream_rules"
require_relative "stopper"
require_relative "validator"

module X
  module Streaming
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
    # streaming client keeps none between streams. A stream is stopped by breaking or raising from the block that
    # reads it, or from another thread, or the trap of a signal, with {#stop}, which stops a stream that delivers
    # nothing as well. A streaming client that was stopped stays stopped, and
    # {X::Streaming::API#streaming Client#streaming} builds a new one each time it is called, so a streaming client to
    # be stopped is kept in a variable, rather than built again to stop.
    #
    # A stream is opened with X::Client#get_stream, of an app-only copy of the client whose read_timeout is the
    # stream's, so it carries the credentials, headers, and proxy of the client as any request does, and none of its
    # credentials to another origin than the base URL of the client.
    #
    # A streaming client keeps the settings it was built with for as long as it lives, as a client does, so a stream
    # that runs for hours never reads a setting another thread is halfway through changing.
    # {X::Streaming::API#streaming Client#streaming} builds one whose read_timeout, max_reconnects, or on_reconnect
    # differ, the settings a streaming client keeps itself, and it takes the rest of its settings from the client it is
    # built from, which {#client} reads, so a stream that connects differently is opened from a copy of that client:
    # client.with(open_timeout: 2).streaming.
    #
    # @api public
    class ::X::StreamingClient
      # Default timeout for reading from a stream in seconds, half again the 20-second interval of the keep-alive X sends
      DEFAULT_READ_TIMEOUT = 30 # seconds
      # Default maximum number of times in a row to reconnect a stream that drops without delivering an object or a
      # keep-alive
      DEFAULT_MAX_RECONNECTS = ReconnectHandler::DEFAULT_MAX_RECONNECTS
      # The message of the error raised for a stream without a block to deliver its objects to
      NO_BLOCK_MESSAGE = "stream takes a block, which receives each object the stream delivers"
      private_constant :NO_BLOCK_MESSAGE
      # The message of the error raised for a stream the server ended, which a stream reconnects after as after a drop
      ENDED_MESSAGE = "The stream ended"
      private_constant :ENDED_MESSAGE
      # The endpoint that reads and changes the rules the filtered stream matches posts against
      RULES_ENDPOINT = "tweets/search/stream/rules"
      private_constant :RULES_ENDPOINT
      # The classes the rules endpoints parse into, whatever parsing classes the client defaults to
      JSON_CLASSES = {array_class: Array, object_class: Hash}.freeze
      private_constant :JSON_CLASSES
      # The message of the error raised for Marshal or YAML, which names what refused it, as a client's does
      REFUSAL_MESSAGE = "%s holds credentials, which %s would write in the clear wherever it is kept; keep the " \
        "credentials in a secret store, and the X::OAuth2Tokens save_tokens is passed, and build it again from them"
      private_constant :REFUSAL_MESSAGE

      # The client the stream authenticates and parses with
      # @api public
      # @return [Client] the client
      # @example Read the base URL of a stream
      #   streaming_client.client.base_url
      attr_reader :client

      # The callable passed the error that dropped a stream and its wait to reconnect
      #
      # A stream that drops reconnects up to max_reconnects times in a row, without end by default, so one that can
      # never connect, as with a host that does not resolve, or a proxy that refuses it, would reconnect in silence
      # for as long as it runs; only a certificate that does not verify raises at once. on_reconnect is passed the error that dropped
      # the stream, such as an X::NetworkError or an X::ServiceUnavailable, and the seconds the stream waits before it
      # reconnects, before each wait, so it can report the reconnects, or give up on them by calling {#stop}, after
      # which the stream returns nil rather than reconnect. An error it raises stops the stream, and reaches the
      # caller as it was raised, as an error of the block of the stream does. A stop does not cut it short, as it does
      # not the block of the stream.
      #
      # It is called with these two arguments and no others, the error, which is never nil, since a stream reconnects
      # only after one, and the wait, and every release of 1.x calls it so, so a lambda that takes exactly two, as
      # ->(error, wait) does, serves each of them. What a later release of 1.x tells of a reconnect beside them, it
      # passes to a hook of its own rather than to this one.
      #
      # @api public
      # @return [#call, nil] the callable, or nil for none
      # @example Read the callable passed each reconnect
      #   streaming_client.on_reconnect
      attr_reader :on_reconnect

      # Initialize a client for the streaming endpoints
      #
      # @api public
      # @param client [Client] the client whose credentials, base URL, and settings the stream uses
      # @param read_timeout [Integer, Float, nil] the timeout for reading from a stream in seconds, at least 25, five more
      #   than the 20 seconds between the keep-alives X sends a quiet stream, or nil for none, which leaves a stream X
      #   stopped sending to open until the operating system gives up on its connection
      # @param max_reconnects [Integer, Float] the maximum number of times in a row to reconnect a stream that drops
      #   without delivering an object or a keep-alive, or Float::INFINITY, the default, for no limit
      # @param on_reconnect [#call, nil] a callable passed the error that dropped a stream and the seconds the stream
      #   waits before it reconnects, before each wait, or nil, the default, for none; see {#on_reconnect}
      # @return [StreamingClient] a new instance
      # @raise [ArgumentError] if the read timeout is neither a finite number of seconds of at least 25 nor nil, the
      #   maximum number of reconnects is neither a count nor Float::INFINITY, or on_reconnect neither responds to call
      #   nor is nil
      # @example Create a streaming client
      #   streaming_client = X::StreamingClient.new(client, max_reconnects: 5)
      # @example Give up on a stream that has failed to connect for minutes, rather than reconnect it without end
      #   streaming_client = X::StreamingClient.new(client, on_reconnect: lambda do |error, wait|
      #     logger.warn("#{error.class}: #{error.message}; reconnecting in #{wait} seconds")
      #     streaming_client.stop if error.is_a?(X::NetworkError) && wait >= 16
      #   end)
      def initialize(client, read_timeout: DEFAULT_READ_TIMEOUT, max_reconnects: DEFAULT_MAX_RECONNECTS, on_reconnect: nil)
        @client = client
        @on_response = Stopper.guarding(client.on_response)
        @stream_client = client.with(read_timeout: Validator.read_timeout!(:read_timeout, read_timeout), on_response: CallbackError.tagging(@on_response))
        @on_reconnect = Validator.callable!(:on_reconnect, on_reconnect)
        @reconnect_handler = ReconnectHandler.new(max_reconnects:, max_rate_limit_wait: client.max_rate_limit_wait, on_reconnect: Stopper.guarding(@on_reconnect))
        @stream_parser = StreamParser.new
        @stopper = Stopper.new
      end

      # The timeout for reading from a stream, in seconds
      # @api public
      # @return [Integer, Float, nil] the timeout, or nil for none
      # @example Get the read timeout
      #   streaming_client.read_timeout # => 30
      def read_timeout = @stream_client.read_timeout

      # The maximum number of times in a row to reconnect a stream
      #
      # A stream is reconnected when it drops, and the count starts over each time it delivers an object or reads the
      # keep-alive X sends every 20 seconds, so that a stream that is quiet but connected never runs out of reconnects.
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
      # the app's bearer token nor its API key and secret has no app_only client, so it opens the stream as the user,
      # which X refuses with 403 Forbidden, raising Forbidden, as any request X refuses the credentials of a client for
      # does. A bearer token X rejects with 401 Unauthorized, as it does one that was invalidated, is fetched again with
      # the API key and secret the app_only client holds, as it is for a request, and the stream is opened once more
      # with it. A stream that drops, or that X disconnects with an operational-disconnect, reconnects, backing off as X
      # recommends, up to max_reconnects times in a row. The API bills each object a stream delivers, so the client's
      # on_response receives each one, as well as a failed response. An error on_response or the object_class raises
      # stops the stream, and reaches the caller as it was raised, even an error of the X API, such as the
      # X::ServiceUnavailable of a request on_response made, which a stream that dropped reconnects after.
      #
      # Reconnects are unlimited by default, and made in silence but for on_reconnect, so a stream that cannot connect,
      # as for a host that does not resolve or a network that is down, reconnects every 16 seconds, once its backoff has
      # grown that long, for as long as it runs. Set max_reconnects to give up after that many in a row, when the stream
      # raises the error of the last, or pass an on_reconnect that calls {#stop}, after which the stream returns nil.
      # Only a certificate that does not verify, which will not verify the next time either, raises at once, as an
      # X::NetworkError whose cause is the OpenSSL::SSL::SSLError.
      #
      # A stream runs until its block stops it: break out of the block to stop the stream and return a value, throw to
      # unwind to a catch further out, or raise, which stops the stream even where a drop would have reconnected, and
      # reaches the caller unchanged, a StopIteration included. Another thread stops it with {#stop}, which ends a
      # stream that delivers nothing as well, when it returns nil, as a stream of a streaming client that was stopped
      # does at once, without a request.
      #
      # @api public
      # @param endpoint [String] the streaming API endpoint, relative to the base URL with or without a leading slash
      # @param params [Hash, nil] query parameters appended to the endpoint
      # @param headers [Hash] additional headers for the request, sent in place of the client's headers of the same
      #   name, which are themselves sent in place of the defaults of the gem
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class, #from_response] the class for parsing JSON objects, or one that responds to
      #   from_response and builds the result from each whole object the stream delivers; see X::Client
      # @yield [Hash, Array] each parsed JSON object from the stream
      # @return [Object, nil] what the block broke with, or nil for a stream {#stop} stopped, or was called before
      # @raise [ArgumentError] if no block is given, or the endpoint is not a valid URL, or does not resolve to an http or
      #   https URL, before the stream is opened
      # @raise [ArgumentError] if array_class is not a Class, or object_class is neither a Class nor responds to
      #   from_response, before the stream is opened
      # @raise [NetworkError] if the stream ends or drops, or cannot connect, with no reconnects left, or at once if the
      #   certificate of the connection does not verify
      # @raise [HTTPError] if the response is not successful and the stream may not reconnect, or asks in its
      #   Retry-After header for a wait longer than the max_rate_limit_wait of the client
      # @raise [StreamError] if a line holds errors and no data, which the stream reconnects after only when each is an
      #   operational-disconnect, and then raises once it has no reconnects left
      # @example Stream filtered posts
      #   streaming_client.stream("tweets/search/stream") { |post| puts post }
      # @example Stop the stream from its block
      #   first = streaming_client.stream("tweets/search/stream") { |post| break post }
      def stream(endpoint, params: nil, headers: {}, array_class: client.default_array_class,
        object_class: client.default_object_class, &block)
        raise ArgumentError, NO_BLOCK_MESSAGE if block.nil?

        Validator.parsing_classes!(array_class:, object_class:)
        consumer = ->(object) { Stopper.guard { block.call(object) } }
        @stopper.run do
          @reconnect_handler.handle(consumer) do |deliver, alive|
            app_only(@stream_client).get_stream(endpoint, params:, headers:) { |response| read(response, array_class:, object_class:, alive:, &deliver) }
          end
        end
      end

      # Stop every stream this streaming client runs, now and from then on
      #
      # A stream waits on the API for most of its life, for the next object, the keep-alive X sends every 20 seconds,
      # or the next reconnect, so its block, which runs only when an object arrives, cannot stop a stream that delivers
      # nothing. This stops each stream running in another thread, or in this one, the next time it waits on the API,
      # at once for a stream waiting now, closing its connection, and the stream returns nil. A block, or the
      # on_response of the client, that is running when a stream is stopped runs to its end first, so that what it
      # does with an object, or on_response with a failed response, is never cut short.
      #
      # A streaming client that was stopped stays stopped: a stream it is asked to run later, as one a thread started
      # just before stop may not yet have opened, returns nil at once, without a request.
      # {X::Streaming::API#streaming Client#streaming} builds a new streaming client to stream with again, and builds
      # another each time it is called, so stop is called on the streaming client the stream runs on, kept in a
      # variable, not on one a second call builds. It may be called from the trap of a signal, and waits for no lock,
      # so it may return before the streams it stops have ended.
      #
      # @api public
      # @return [nil]
      # @example Stop a stream that runs in a thread of its own
      #   streaming_client = client.streaming
      #   reader = Thread.new { streaming_client.stream("tweets/search/stream") { |post| queue << post } }
      #   streaming_client.stop
      #   reader.join
      # @example Stop a stream when the process is interrupted
      #   streaming_client = client.streaming
      #   Signal.trap("INT") { streaming_client.stop }
      #   streaming_client.stream("tweets/search/stream") { |post| puts post }
      def stop = @stopper.stop

      # Whether {#stop} was called, after which each stream returns nil at once
      #
      # @api public
      # @return [Boolean] true once {#stop} was called
      # @example Check whether a streaming client was stopped
      #   streaming_client.stopped? # => false
      def stopped? = @stopper.stopped?

      # The rules the filtered stream matches posts against
      #
      # The rules of an app are read, added, and deleted through a streaming client because they belong to the stream:
      # they are what the filtered stream delivers, and they take the app-only authentication a stream takes. The API
      # returns the rules a page at a time, and every page is read, so the rules are all of them. A page that names an
      # empty next token, or the token of a page already read, is the last, as a page that names none is. The pages
      # are read with while rather than Kernel#loop, which rescues StopIteration, so that a StopIteration the
      # on_response of the client raises while a page is read reaches the caller, rather than end the reading in
      # silence with the rules of the pages before it.
      #
      # @api public
      # @param params [Hash, nil] query parameters appended to the endpoint of each page
      # @return [Array<StreamRule>] the rules, frozen, empty if the app has none
      # @raise [HTTPError] if the API refuses the request
      # @example Print the rules of the app
      #   streaming_client.rules.each { |rule| puts "#{rule.tag}: #{rule.value}" }
      # @example Read two rules by identifier
      #   streaming_client.rules(params: {ids: "1,2"})
      def rules(params: nil)
        rules = [] #: Array[StreamRule]
        spent = [] #: Array[String]
        while (token = read_rules(params, into: rules, spent:))
          spent << token
          params = params.to_h.merge(pagination_token: token)
        end
        rules.freeze
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
      # block, a rule that was not added raises RulesRejected, which holds the rules that were as added, so that
      # neither a rule the app already has nor one a dry run found invalid is passed over in silence.
      #
      # @api public
      # @param rules [Array<StreamRule, Hash, String>, StreamRule, Hash, String] the rules to add
      # @param dry_run [Boolean] true to have the API check the rules and add none of them
      # @yieldparam problem [Problem] each rule the API did not add, and why, such as a DuplicateRule
      # @return [Array<StreamRule>] the rules that were added, frozen, each holding the id the API gave it, empty if
      #   none were given
      # @raise [ArgumentError] if something is neither a StreamRule, a Hash that holds a value, nor a String
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
        added = StreamRules.rules_of(body)
        reporting(body, {added:}, &)
        added
      end

      # Delete rules of the filtered stream
      #
      # A rule is deleted by its identifier, or by the value it matches: a StreamRule the API returned, a Hash that holds
      # an id, an Integer, or an X::MatchingRule is deleted by identifier, so what {#rules} returned deletes itself, as
      # do the rules a post of x-objects matched, which its matching_rules holds, and a StreamRule or a Hash that holds
      # a value and no identifier, or a String, is deleted by value, so what add_rules was given deletes what it added.
      # Anything else raises before a request, even something else with an id, such as a post, whose identifier would
      # delete whichever rule shared it. No rules delete none, and send no request, since the API refuses a deletion
      # that names no rule.
      #
      # The API deletes the rules it can and reports the rest, such as a rule the app does not have, as errors of a
      # response that otherwise succeeds. The number of rules that were deleted is returned, and each problem the API
      # reported is yielded, as add_rules yields the rules it did not add, or, without a block, raises RulesRejected,
      # which holds the number as deleted_count.
      #
      # @api public
      # @param rules [Array<StreamRule, Hash, String, Integer, X::MatchingRule>, StreamRule, Hash, String, Integer,
      #   X::MatchingRule] the rules to delete, the values they match, or their identifiers
      # @param dry_run [Boolean] true to have the API check the rules and delete none of them
      # @yieldparam problem [Problem] each problem the API reported of the rules it did not delete
      # @return [Integer] the number of rules deleted, or that a dry run would delete, 0 if none were given
      # @raise [ArgumentError] if something is neither a rule nor the identifier of one, or holds an identifier that is
      #   neither an Integer that is not negative nor a String of digits alone
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
      # @example Delete the rules a post of x-objects matched
      #   streaming_client.delete_rules(post.matching_rules)
      def delete_rules(rules, dry_run: false, &)
        rules = StreamRules.each_rule(rules)
        return 0 if rules.empty?

        ids, values = rules.partition { |rule| StreamRules.identifier_of(rule) }
        body = change_rules({delete: StreamRules.deletion(ids, values)}, dry_run:)
        deleted_count = body.to_h.dig("meta", "summary", "deleted").to_i
        reporting(body, {deleted_count:}, &)
        deleted_count
      end

      # Refuse to be written with Marshal, which would write its credentials
      #
      # @api public
      # @return [void]
      # @raise [TypeError] always
      # @example Keep the settings of a stream, rather than the streaming client
      #   settings = {read_timeout: streaming_client.read_timeout, max_reconnects: streaming_client.max_reconnects}
      def marshal_dump = raise(TypeError, format(REFUSAL_MESSAGE, self.class, "Marshal"))

      # Refuse to be written as YAML, which would write its credentials
      #
      # YAML reads no marshal_dump, and writes every instance variable of an object that does not say how it is
      # written, the client and its credentials among them, so it is refused as Marshal is.
      #
      # @api public
      # @param _coder [Psych::Coder] the coder YAML would write the streaming client with
      # @return [void]
      # @raise [TypeError] always
      # @example Keep the settings of a stream, rather than the streaming client
      #   YAML.dump({"read_timeout" => streaming_client.read_timeout})
      def encode_with(_coder) = raise(TypeError, format(REFUSAL_MESSAGE, self.class, "YAML"))

      # Refuse to be read as JSON, which would write its credentials
      #
      # ActiveSupport's Object#as_json reads every instance variable of an object that does not say how it is read,
      # the client and its credentials among them, so it is refused as YAML is.
      #
      # @api public
      # @return [void]
      # @raise [TypeError] always
      # @example Render the settings of a stream, rather than the streaming client
      #   render json: {read_timeout: streaming_client.read_timeout}
      def as_json(*) = raise(TypeError, format(REFUSAL_MESSAGE, self.class, "JSON"))

      # Refuse to be written as JSON, which would write its credentials
      #
      # It raises as {#as_json} does, for the reason that says, so that JSON.generate refuses a streaming client within
      # what it writes as well.
      #
      # @api public
      # @param _state [JSON::State, nil] the state JSON would write the streaming client with
      # @return [void]
      # @raise [TypeError] always
      # @example Log the settings of a stream, rather than the streaming client
      #   logger.info(JSON.generate(read_timeout: streaming_client.read_timeout))
      def to_json(_state = nil) = raise(TypeError, format(REFUSAL_MESSAGE, self.class, "JSON"))

      private

      # Read a page of rules, as the app, adding them to those of the pages before it
      # @api private
      # @param params [Hash, nil] query parameters appended to the endpoint
      # @param into [Array<StreamRule>] the rules of the pages before it, which the rules of the page are added to
      # @param spent [Array<String>] the tokens that fetched the pages before it
      # @return [String, nil] the token of the page after it, or nil if it is the last
      def read_rules(params, into:, spent:)
        body = app_client.get(RULES_ENDPOINT, params:, **JSON_CLASSES)
        into.concat(StreamRules.rules_of(body))
        StreamRules.next_token(body, spent)
      end

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
      # @param changed [Hash{Symbol => Object}] what the change returns, as the error holds it: the rules added, or the
      #   number of rules deleted
      # @yieldparam problem [Problem] each problem the API reported
      # @return [void]
      # @raise [RulesRejected] if the API reported a problem and no block was given
      def reporting(body, changed)
        problems = Problem.all_from(body)
        if block_given?
          problems.each { |problem| yield problem }
        elsif problems.any?
          raise RulesRejected.new(problems:, **changed)
        end
      end

      # Read a stream once, and deliver each object it sends until it ends
      #
      # X holds a stream open until it drops it, so a stream the server ends raises a NetworkError, as one that drops
      # does, which a stream reconnects after, and which reaches the caller once it has no reconnects left. A stream the
      # server ends within a line raises it too, since the parser drops what it read of the line.
      #
      # @api private
      # @param response [Net::HTTPResponse] the response of the stream, whose body is not yet read
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class, #from_response] the class for parsing JSON objects
      # @param alive [#call] the callable to call for each keep-alive the stream reads
      # @yield [Hash, Array] each parsed JSON object from the stream
      # @return [void]
      # @raise [NetworkError] once the stream ends
      def read(response, array_class:, object_class:, alive:, &)
        @stream_parser.process(response:, array_class:, object_class:, client:, on_line: ->(line) { report(response, line) }, on_keep_alive: alive, &)
        raise NetworkError.new(ENDED_MESSAGE, http_method: :get, uri: response.uri)
      end

      # The client the rules are read and changed with, as the app where it can
      # @api private
      # @return [Client] the app-only client, or the client itself
      def app_client = app_only(client)

      # The app-only client of a client, or the client itself for one that has none
      #
      # A client that authenticates with OAuth 2.0 as a user and holds no credentials of the app has no app-only
      # client, so it requests as the user, and X answers as it answers those credentials, refusing them with 403
      # Forbidden, rather than be refused before the request.
      #
      # @api private
      # @param client [Client] the client
      # @return [Client] the app-only client, or the client itself
      def app_only(client)
        client.app_only
      rescue UnsupportedOperation
        client
      end

      # Pass one object of a stream to the client's on_response, guarded from stop
      #
      # The stream is opened with a copy of the client whose on_response calls the client's with Stopper.guard, which
      # X::Client#get_stream passes a failed response, as this passes it each object. That copy tags the error the
      # client's raises as a CallbackError, since X::Client#get_stream raises it as it was, where an
      # X::ServiceUnavailable or an X::NetworkError would be taken for the stream's own and reconnected after, so this
      # calls the client's on_response, guarded, rather than that copy's, whose error StreamParser tags as it tags the
      # error of the object_class.
      #
      # @api private
      # @param response [Net::HTTPResponse] the response of the stream
      # @param line [String] the object the stream delivered
      # @return [void]
      def report(response, line)
        uri = response.uri #: URI::Generic
        @on_response&.call(Response.new(http_response: response, http_method: :get, uri:, body: line))
      end
    end
  end
end
