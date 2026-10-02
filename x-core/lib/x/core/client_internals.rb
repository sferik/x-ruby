# frozen_string_literal: true

require "monitor"
require "uri"
require_relative "app_only_authenticator"
require_relative "authenticator"
require_relative "bearer_token_authenticator"
require_relative "client_app_only"
require_relative "client_credentials"
require_relative "client_settings"
require_relative "client_token_refresh"
require_relative "connection"
require_relative "credential_holder"
require_relative "credential_validator"
require_relative "errors/callback_error"
require_relative "oauth1_authenticator"
require_relative "oauth2_authenticator"
require_relative "origin"
require_relative "proxy_setting"
require_relative "request_builder"
require_relative "request_encoding"
require_relative "response_parser"
require_relative "setting_validator"
require_relative "stream_body"

module X
  module Core
    # The credentials, settings, connection, handlers, and authenticator of a client, and the methods that send its
    # requests with them
    #
    # X::Client is the class that x-objects and x-uploader include their methods into, and each is released apart
    # from x-core, so a later version of either may name a method as it likes. A method of theirs would take the
    # place of a private method of the client of the same name, and a client whose own methods called that one would
    # call theirs in its place. So a client holds its state here and calls on this object, whose methods none of
    # theirs can take the place of, and has no methods of its own but those of its public API and initialize.
    #
    # A client holds one of these for as long as it lives, and passes itself to a method that needs it, such as one
    # that parses a response for it, rather than this holding the client, so that a copy of the client made with dup,
    # which holds the same internals, as it held the same state before, passes itself in turn.
    #
    # @api private
    class ClientInternals
      include ClientAppOnly
      include ClientCredentials
      include ClientSettings
      include CredentialHolder
      include ClientTokenRefresh
      include ProxySetting

      # Content type of a form-encoded request body
      FORM_CONTENT_TYPE = "application/x-www-form-urlencoded; charset=utf-8"
      private_constant :FORM_CONTENT_TYPE

      # The authenticator for API requests
      #
      # {Client#authenticator} returns it.
      #
      # @api private
      # @return [Authenticator] the authenticator instance
      attr_reader :authenticator

      # The callable passed the OAuth2Tokens of each refresh
      #
      # {Client#save_tokens} returns it.
      #
      # @api private
      # @return [#call, nil] the callable, or nil for none
      attr_reader :save_tokens

      # The callable a refresh reads the stored OAuth2Tokens with
      #
      # {Client#load_tokens} returns it.
      #
      # @api private
      # @return [#call, nil] the callable, or nil for none
      attr_reader :load_tokens

      # The internals of a client
      #
      # A copy of a client, which {#with} builds, reads the internals of the client it copies with this.
      #
      # @api private
      # @param client [Client] the client
      # @return [ClientInternals] the internals of the client
      def self.of(client) = client.instance_variable_get(:@internals)

      # Initialize the internals of a client, with the options its initialize was given
      #
      # The authenticator is taken last, since a client that raised must leave an authenticator it was given alone.
      #
      # @api private
      # @param client [Client] the client these are the internals of
      # @return [ClientInternals] a new instance
      # @raise [ArgumentError] if an option is refused, as {Client#initialize} states
      def initialize(client, api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:, client_id:,
        client_secret:, refresh_token:, expires_at:, scopes:, authenticator:, base_url:, open_timeout:, read_timeout:,
        write_timeout:, keep_alive_timeout:, debug_output:, proxy_url:, default_array_class:, default_object_class:,
        headers:, max_redirects:, max_rate_limit_retries:, max_rate_limit_wait:, max_retries:, on_response:,
        save_tokens:, load_tokens:)
        @proxy_url = proxy_url
        @connection = Connection.new(open_timeout:, read_timeout:, write_timeout:, keep_alive_timeout:, debug_output:, proxy_url:)
        @app_only_monitor = Monitor.new
        @request_builder = RequestBuilder.new
        @response_parser = ResponseParser.new
        initialize_credentials(api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:, client_id:, client_secret:, refresh_token:, expires_at:, scopes:)
        validate_credentials!(authenticator)
        initialize_settings(base_url:, default_array_class:, default_object_class:, headers:, on_response:, max_redirects:, max_rate_limit_retries:, max_rate_limit_wait:, max_retries:)
        initialize_token_hooks(save_tokens:, load_tokens:)
        initialize_authenticator(client, authenticator)
      end

      # Summarize the internals of a client without revealing credentials
      #
      # They hold the credentials of the client, so they are summarized as {Client#inspect} summarizes the client.
      #
      # @api private
      # @return [String] the class name, base URL, and authenticator
      def inspect = "#<#{self.class} base_url=#{base_url.inspect} authenticator=#{authenticator.inspect}>"

      # Copy a client with some of its options changed
      #
      # It is what {Client#with} does. The internals of the copy share the authenticator and the connections of these
      # as that states.
      #
      # @api private
      # @param client [Client] the client these are the internals of
      # @param options [Hash{Symbol => Object}] the options to change, as accepted by initialize
      # @return [Client] a new client with the same credentials and settings, apart from the options given
      def with(client, options)
        client.class.new(**without_tokens_of_client({**settings, **with_credentials(options)}, options)).tap do |copy|
          internals = ClientInternals.of(copy)
          internals.__send__(:share_authenticator, copy, authenticator, options)
          internals.__send__(:share_app_token, self)
          internals.__send__(:share_connection, @connection)
        end
      end

      # Close the connections the client keeps open between requests
      #
      # It is what {Client#close} does.
      #
      # @api private
      # @return [void]
      def close = @connection.close

      # Execute an HTTP request to the X API
      #
      # An error a callback raised, which the request tags as a CallbackError so that no handler sends the request
      # again, waits out a rate limit, or refreshes a token for it, is raised as it was, once the handlers are left,
      # noted as a callback's, so that Client#with_retries does not send the request again for it either.
      #
      # @api private
      # @param client [Client] the client these are the internals of, which a response is parsed for
      # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
      def execute_request(client, http_method, endpoint, params:, headers:, array_class:, object_class:, body: nil, form: nil, &block)
        SettingValidator.parsing_classes!(array_class:, object_class:)
        SettingValidator.headers!(headers)
        uri = RequestEncoding.uri_for(base_url, endpoint, params)
        headers = headers_for(form.nil? ? headers : RequestBuilder.merge_headers({"Content-Type" => FORM_CONTENT_TYPE}, headers))
        @retry_handler.handle(idempotent: RequestBuilder.idempotent?(http_method)) do
          @rate_limit_handler.handle { refreshing_rejected_token(client) { perform(client, http_method, uri, body: RequestEncoding.encode_body(body, form), headers:, array_class:, object_class:, &block) } }
        end
      rescue CallbackError => e
        raise CallbackError.untag(e)
      end

      # Open a GET request whose body the block reads as it arrives
      #
      # It is what {Client#get_stream} does. An error the block raises, but for the errors of a socket, which raise a
      # NetworkError, is tagged as a CallbackError, so that no rejected token is refreshed for it, and raised as it was
      # once the request is left.
      #
      # @api private
      # @param client [Client] the client these are the internals of
      # @param endpoint [String] the endpoint, relative to the base URL
      # @param params [Hash, nil] query parameters appended to the endpoint
      # @param headers [Hash] additional headers for the request
      # @yieldparam http_response [Net::HTTPResponse] the successful response, whose body is not yet read
      # @return [Object] what the block returns
      def execute_stream(client, endpoint, params:, headers:, &)
        uri = RequestEncoding.uri_for(base_url, endpoint, params)
        headers = headers_for(SettingValidator.headers!(headers))
        refreshing_rejected_token(client) { perform_stream(uri, headers:, &) }
      rescue CallbackError => e
        raise CallbackError.untag(e)
      end

      private

      # Open a GET request once, and pass its response to the block if it succeeded
      #
      # A request to another origin than the base URL carries none of the client's credentials, as any other does.
      #
      # @api private
      # @param uri [URI::Generic] the URI of the request
      # @param headers [Hash] the headers of the request, beside those of the client
      # @yieldparam http_response [Net::HTTPResponse] the successful response
      # @return [Object] what the block returns
      # @raise [HTTPError] if the response is not successful
      # @raise [CallbackError] if on_response or the block raises an error that is not one of a socket
      def perform_stream(uri, headers:)
        authenticator, headers = Origin.credentials_for(from: URI(base_url), to: uri, authenticator: self.authenticator, headers:)
        request = @request_builder.build(http_method: :get, uri:, headers:, authenticator:)
        @connection.perform_stream(request:) do |response|
          stream_failed(uri, response, request) unless response.is_a?(Net::HTTPSuccess)
          reading(response) { |body| yield body }
        end
      end

      # Raise the error of a stream that failed
      #
      # Its body is read whole, tagged UTF-8 as the body of {Connection#perform} is, before the block of the request
      # ends, so that on_response and the error can read it however long after it was raised.
      #
      # @api private
      # @param uri [URI::Generic] the URI of the request
      # @param response [Net::HTTPResponse] the failed response, whose body is not yet read
      # @param request [Net::HTTPRequest] the request the response answers
      # @return [void]
      # @raise [HTTPError] the error of the response
      # @raise [CallbackError] if on_response raises
      def stream_failed(uri, response, request)
        response.body_encoding = Encoding::UTF_8
        response.body
        CallbackError.tagging { report(:get, uri, response) }
        raise @response_parser.error(response, request)
      end

      # Run the block of a stream, tagging its errors but those of its socket
      #
      # The errors of the socket are those read_body raised from it, as StreamBody notes them, which the connection
      # raises as a NetworkError, and any other error is the block's own, whatever its class, which is raised as it
      # was, as is the error of a socket the block raised of its own, such as the IOError of a file it wrote to.
      #
      # @api private
      # @param response [Net::HTTPResponse] the successful response, whose body is not yet read
      # @yieldparam body [Net::HTTPResponse] the response, which notes the errors of the socket its body is read from
      # @return [Object] what the block returns
      # @raise [CallbackError] if the block raises an error that read_body did not raise from the socket
      def reading(response)
        yield response.extend(StreamBody)
      rescue => e
        raise if StreamBody.socket_error?(e)

        raise CallbackError, e
      end

      # Perform a request once, following redirects and parsing the response
      #
      # A request to another origin than the base URL carries none of the client's credentials, as a redirect to one
      # carries none of them. The error on_response or the block of the request raises, as the error from_response
      # raises, is tagged as a CallbackError, so that it is not taken for an error of the response. The response is
      # reported, and its error named, for the request it answers, which a redirect may have sent to another URI with
      # another method than the request was made with.
      #
      # @api private
      # @param client [Client] the client these are the internals of, which a response is parsed for
      # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
      def perform(client, http_method, uri, body:, headers:, array_class:, object_class:, &)
        authenticator, headers = Origin.credentials_for(from: URI(base_url), to: uri, authenticator: self.authenticator, headers:)
        request = @request_builder.build(http_method:, uri:, body:, headers:, authenticator:)
        response, request = @redirect_handler.follow(response: @connection.perform(request:), request:, headers:, authenticator:)
        CallbackError.tagging { report(request.method, request.uri, response, &) }
        @response_parser.parse(response:, array_class:, object_class:, client:, request:)
      end
    end
    private_constant :ClientInternals
  end
end
