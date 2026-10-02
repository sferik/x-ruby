# frozen_string_literal: true

require "json"
require "time"
require_relative "error"
require_relative "../built_response"
require_relative "../problem"
require_relative "../request_context"
require_relative "../response_headers"

module X
  module Core
    # Base class for HTTP errors from the X API
    #
    # The message is what the API said went wrong, read from the body of the response, behind the method and path of
    # the request it answered. {#body} holds that body as it arrived, {#headers} the headers it came with, and
    # {#problem} the problem it describes the failure with as a whole, and {#problems} each problem it names, for code
    # that acts on the reason rather than logging it. {#http_method} and {#uri} are the request the API refused.
    #
    # A 4xx raises a ClientError, a 5xx a ServerError, and a body that is not JSON an InvalidResponse, each a subclass
    # of this. It is raised itself for a redirect the client does not follow: a 300 Multiple Choices, 304 Not Modified,
    # or 305 Use Proxy, and a redirect whose Location is missing, is not a valid URL, or is not an HTTP or HTTPS URL.
    #
    # @api public
    class ::X::HTTPError < Error
      include RequestContext
      include ResponseHeaders

      # Regular expression to match JSON content types
      JSON_CONTENT_TYPE_REGEXP = %r{application/(problem\+|)json}
      private_constant :JSON_CONTENT_TYPE_REGEXP
      # The keys of a body that describes the failure itself, rather than naming the errors of the request
      PROBLEM_KEYS = %w[title detail type error].freeze
      private_constant :PROBLEM_KEYS
      # The header that says how long to wait before sending the request again
      RETRY_AFTER_HEADER = "retry-after"
      private_constant :RETRY_AFTER_HEADER
      # The value of a Retry-After header that counts seconds, rather than naming the time to wait until
      RETRY_AFTER_SECONDS = /\A\d+\z/
      private_constant :RETRY_AFTER_SECONDS
      # The message of the error raised for an HTTPError itself, which has no status, given neither a response nor one
      ANY_STATUS = "X::HTTPError is raised for a response of any status, so it is built with the status: of one, or the " \
        "http_response: itself; raise the error of the status, such as X::NotFound, to build one without either"
      private_constant :ANY_STATUS

      # The response itself, as the client received it
      #
      # It is an escape hatch, for what the error does not read: the status is {#status}, the headers are
      # {#headers}, and the body is {#body}. It is the Net::HTTP response the client sent the request with, or the one
      # built of the status, headers, and body the error was given.
      #
      # @api public
      # @return [Net::HTTPResponse] the HTTP response
      # @example Read the reason phrase of the status line
      #   error.http_response.message # => "Too Many Requests"
      attr_reader :http_response

      # The problems the API named in the body of the response
      #
      # They are the errors the body names, such as each parameter of the request the API refused, or else the
      # problem the body describes itself, which is {#problem}.
      #
      # @api public
      # @return [Array<Problem>] the problems, frozen, empty for a response that describes none in JSON
      # @example Name each parameter the API refused
      #   error.problems.map(&:parameter) # => ["ids", "user.fields"]
      attr_reader :problems

      # The problem the API described the failure with as a whole
      #
      # It is the problem the body of the response describes itself, by its title, detail, type, and status, whether
      # or not the body names errors of its own, which are {#problems}, so its type reads the kind of failure alike
      # for a request the API refused a parameter of and for one it refused to authorize; its attributes are the whole
      # body. A body that describes no problem of its own, but names errors, as the responses of v1.1 do, is described
      # by the first of them.
      #
      # @api public
      # @return [Problem, nil] the problem, or nil for a response that describes none in JSON
      # @example Tell a request the API found invalid from one it refused to authorize
      #   error.problem&.type # => "https://api.twitter.com/2/problems/invalid-request"
      # @example Act on the reason rather than the status
      #   wait_for_the_next_month if error.problem&.usage_capped?
      attr_reader :problem

      # Initialize a new HTTPError
      #
      # Public, so that code that rescues an HTTPError, or a subclass such as NotFound, can be tested with one built from
      # the status, headers, and body of a response, or from a Net::HTTP response, as x-core builds each from the
      # response it parses. The error names the request, when given its method and URI, as x-core names the request the
      # response answers.
      #
      # It can be raised as any other exception is, as in raise X::NotFound, or raise X::NotFound, "gone", for a test
      # double that stands in for a client: an error of a status, such as NotFound, given neither a response nor a
      # status, is built with the status x-core raises it for, a ClientError or ServerError with the first of its kind,
      # 400 or 500, and an InvalidResponse with 200. An HTTPError itself, which is raised for a status of any kind, must
      # be given one. A message given is the message of the error, in place of the one read from the body.
      #
      # @api public
      # @param message [String, nil] the message, or nil for the one the body describes the failure with
      # @param http_response [Net::HTTPResponse, nil] the HTTP response, or nil for one built of the status, headers,
      #   and body
      # @param status [Integer, nil] the status of the response, from 100 to 599, when it is not given, or nil for the
      #   status of the class
      # @param headers [Hash{String => String}, nil] the headers of the response, when it is not given
      # @param body [String, nil] the body of the response, when it is not given
      # @param http_method [Symbol, String, nil] the method of the request the response answers, in any case
      # @param uri [URI::Generic, nil] the URI of the request the response answers
      # @return [HTTPError] a new instance
      # @raise [ArgumentError] if the HTTP response is given beside a status, headers, or a body, or neither it nor a
      #   status is given to an HTTPError itself, or the status is not from 100 to 599, or the headers are not a Hash of
      #   names to values
      # @example Create the error of a user that does not exist
      #   error = X::NotFound.new(status: 404, headers: {"content-type" => "application/json"},
      #     body: %({"title":"Not Found Error","detail":"Could not find user."}))
      # @example Raise the error of a rate limit from a test double
      #   raise X::TooManyRequests, "Too Many Requests"
      # @example Create an HTTP error from a response
      #   error = X::HTTPError.new(http_response: response, http_method: :get, uri: URI("https://api.x.com/2/users/me"))
      def initialize(message = nil, http_response: nil, status: nil, headers: nil, body: nil, http_method: nil, uri: nil)
        @http_response = built_response(http_response, status:, headers:, body:)
        name_request(http_method, uri)
        parsed = parsed_body
        errors = errors_from(parsed)
        described = (Problem.new(parsed) if describes_problem?(parsed))
        @problems = (errors.empty? ? [described].compact : errors).freeze
        @problem = described || errors.first
        super(message_naming_request(message || message_from(parsed) || @http_response.message))
      end

      # The status an error of this class is built with by default
      #
      # It is the status an error given neither a response nor a status is built with: the status x-core raises the class, or the nearest class it descends from, for, or the first status of
      # the kind of a ClientError or ServerError, 400 or 500.
      #
      # @api private
      # @return [Integer, nil] the status, or nil for an HTTPError itself, which is raised for a status of any kind
      # @example Get the status of a NotFound
      #   X::NotFound.__send__(:default_status) # => 404
      def self.default_status
        parser = Core.const_get(:ResponseParser)
        ancestors.each do |ancestor|
          status = parser::ERROR_MAP.key(ancestor) || parser::STATUS_CLASS_ERRORS.key(ancestor)&.*(100)
          return status if status
        end
        nil
      end
      private_class_method :default_status

      # The HTTP status code, as an Integer like X::Response#status
      #
      # @api public
      # @return [Integer] the HTTP status code
      # @example Handle a status the errors do not name
      #   retry if error.status.eql?(408)
      def status = Integer(http_response.code)

      # The body of the response, as it arrived
      #
      # A server can send any body with an error, so it is the JSON the API describes a failure with, or whatever
      # else was sent in its place, such as the page of a proxy. It is tagged UTF-8, the encoding of the JSON the API
      # sends, and a body that is not valid UTF-8 keeps its bytes, so valid_encoding? tells it apart.
      #
      # @api public
      # @return [String, nil] the body, tagged UTF-8, or nil for a response without one
      # @example Log what the API sent
      #   logger.error(error.body)
      def body = http_response.body

      # The seconds the response asks a request to wait before it is sent again
      #
      # The API sends a Retry-After header with a request it refused for a rate limit, and with some of the responses
      # of a failure of its own, such as a 503 that names the time its endpoint is expected back. The header counts
      # the seconds from when the response was sent, or names the time to wait until. A client waits it out before it
      # sends an idempotent request again, up to a minute; see {Client#initialize}.
      #
      # @api public
      # @return [Integer, nil] the seconds, never negative, or nil for a response that does not say
      # @example Wait as long as the API asks before sending a request again
      #   sleep(error.retry_after || 1)
      def retry_after
        value = http_response[RETRY_AFTER_HEADER]
        return if value.nil?

        value.match?(RETRY_AFTER_SECONDS) ? Integer(value, 10) : seconds_until(value)
      end

      private

      # The HTTP response given, or the one built of the status, headers, and body
      #
      # A response given neither a response nor a status is built with the status of the class, and an HTTPError itself,
      # which has none, raises.
      #
      # @api private
      # @param http_response [Net::HTTPResponse, nil] the HTTP response, or nil to build one
      # @param status [Integer, nil] the status of the response to build, or nil for the status of the class
      # @param headers [Hash{String => String}, nil] the headers of the response to build, or nil for none
      # @param body [String, nil] the body of the response to build, or nil for none
      # @return [Net::HTTPResponse] the HTTP response
      # @raise [ArgumentError] if the error is given neither a response nor a status, and its class has no status, or as
      #   {BuiltResponse.of} raises
      def built_response(http_response, status:, headers:, body:)
        status ||= self.class.__send__(:default_status) if http_response.nil?
        raise ArgumentError, ANY_STATUS if http_response.nil? && status.nil?

        BuiltResponse.of(http_response, status:, headers:, body:)
      end

      # The seconds until the time an HTTP date names
      # @api private
      # @param value [String] the value of the header
      # @return [Integer, nil] the seconds, never negative, or nil if the value names no time
      def seconds_until(value)
        [(Time.httpdate(value) - Time.now).ceil, 0].max
      rescue ArgumentError
        nil
      end

      # The body of the response, parsed as a JSON object
      #
      # A server can send any body with an error, so a body that is not JSON, or that is not the JSON its content
      # type claims, parses to an empty object rather than raise while the error is built.
      #
      # @api private
      # @return [Hash{String => Object}] the parsed body, empty for a body that is not a JSON object
      def parsed_body
        return {} unless json?

        Hash.try_convert(JSON.parse(body.to_s)) || {}
      rescue JSON::ParserError
        {}
      end

      # The problems of the errors a body names
      #
      # @api private
      # @param body [Hash{String => Object}] the parsed body
      # @return [Array<Problem>] a problem for each error the body names that is a JSON object, none if it names none
      def errors_from(body)
        Array(body["errors"]).filter_map { |error| Problem.from(Hash.try_convert(error)) }
      end

      # Check whether a body describes a problem itself, rather than only naming errors
      #
      # @api private
      # @param body [Hash{String => Object}] the parsed body
      # @return [Boolean] true if the body holds a title, detail, type, or error of its own
      def describes_problem?(body) = PROBLEM_KEYS.any? { |key| body.key?(key) }

      # The message a body describes the failure with
      #
      # A body that holds no message leaves the error with the status message of the response.
      #
      # @api private
      # @param body [Hash{String => Object}] the parsed body
      # @return [String, nil] the message, or nil if the body holds none
      def message_from(body)
        message_from_errors(body["errors"]) || message_from_problem(body) || String.try_convert(body["error"])
      end

      # Join the messages of an errors array
      #
      # Each error gives its message, or else its detail or title.
      #
      # @api private
      # @param errors [Object] the errors of the body
      # @return [String, nil] the joined messages, or nil if there are none
      def message_from_errors(errors)
        messages = Array(errors).filter_map do |error|
          Hash.try_convert(error)&.values_at("message", "detail", "title")&.grep(String)&.first
        end
        messages.join(", ") unless messages.empty?
      end

      # The title and detail of a problem, joined
      #
      # A detail that says no more than the title, as the Unauthorized of a 401 does, is left out, rather than
      # repeated behind it.
      #
      # @api private
      # @param body [Hash{String => untyped}] the body
      # @return [String, nil] the title and detail, the title alone if the detail is the same, or nil unless the body
      #   has both
      def message_from_problem(body)
        title = body["title"]
        detail = body["detail"]
        return unless title && detail

        title.eql?(detail) ? title : "#{title}: #{detail}"
      end

      # Check whether the response carries JSON
      # @api private
      # @return [Boolean] true if the response is JSON
      def json?
        JSON_CONTENT_TYPE_REGEXP === http_response["content-type"]
      end
    end
  end
end
