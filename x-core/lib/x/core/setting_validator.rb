# frozen_string_literal: true

require "uri"

module X
  module Core
    # Checks the settings of the handlers of a client when the client is built
    #
    # A setting is compared with a count of attempts or a number of seconds only once a request has failed, so a
    # setting that is not a number, such as a String read from an environment variable, would raise from that
    # comparison, in place of the failure it was compared for. So each is checked when the handler is built, which
    # is when the client that holds it is.
    #
    # A timeout is handed to Net::HTTP, which reads it only once a request waits, so a timeout that is not a number
    # raises from inside Net::HTTP as the first request is sent, and Float::INFINITY raises there too, or ends the
    # thread that Timeout keeps for every timeout of the process, since no deadline can be set that far off. So each
    # is checked when the connection is built, which is when the client that holds it is.
    #
    # The base URL and the headers of a client are read only once a request is built, so a base URL that is no URL,
    # or headers that are not a Hash of names to values, raised from the first request, rather than where the client
    # was given them, so each is checked when the client is built.
    #
    # The classes a response is parsed into are read only once a response has arrived, so a class that cannot parse
    # one, such as the String "Hash", raised once the API had answered, and billed, the request. So the default
    # classes of a client are checked when the client is built, and the classes of a request before it is sent.
    #
    # The debug output of a client is written only once a request is sent, so one that takes no String, such as true,
    # raised a NoMethodError from the first request, an Integer, whose << shifts it, a TypeError, and a String, as
    # the name of a file, was appended every request, with its Authorization header, in place of the file. So it is
    # checked when the connection is built.
    #
    # Internal to x-core: the handlers of redirects, rate limits, and retries, a connection, and a client check their
    # settings with it.
    #
    # @api private
    module SettingValidator
      extend self

      # The message of the error raised for a count that is not an Integer of at least 0
      INVALID_COUNT = "%s must be an Integer of at least 0, not %s"
      # The message of the error raised for seconds that are not a number of at least 0
      INVALID_SECONDS = "%s must be a number of seconds of at least 0, not %s"
      # The message of the error raised for seconds that are not a finite number of at least 0
      INVALID_FINITE_SECONDS = "%s must be a finite number of seconds of at least 0, not %s"
      # The message of the error raised for a timeout that is neither a finite number of seconds of at least 0 nor nil
      INVALID_TIMEOUT = "%s must be a finite number of seconds of at least 0, or nil for no timeout, not %s"
      # The message of the error raised for a base URL that is not an absolute HTTP or HTTPS URL
      INVALID_BASE_URL = "base_url must be an absolute http or https URL with no query or fragment, such as \"https://api.x.com/2/\", not %s"
      # The message of the error raised for a base URL that holds a user or a password, which it leaves out, since
      # either may be a secret
      BASE_URL_WITH_USERINFO = "base_url must hold no user or password, which no request sends"
      # The scheme and authority of a URL whose authority holds a user or a password, before the at sign of the host
      USERINFO = %r{\A[^:/?#]+://[^/?#]*@}
      # The message of the error raised for headers that are not a Hash
      INVALID_HEADERS = "headers must be a Hash of header names to values, not %s"
      # The message of the error raised for a header whose name or value is not what a header takes
      INVALID_HEADER = "headers must name each header with a String or a Symbol and give it a String, " \
        "not %<name>s with %<value>s"
      # The message of the error raised for a callable that does not respond to call
      INVALID_CALLABLE = "%s must respond to call, as a Proc or a lambda does, or be nil, not %s"
      # The message of the error raised for a debug output that takes no String with <<
      INVALID_DEBUG_OUTPUT = "debug_output must take a String with <<, as an IO, a StringIO, or a Logger does, or be nil, not %s"
      # The message of the error raised for a debug output that is a String, as the name of a file is
      DEBUG_OUTPUT_STRING = "debug_output must be an IO, such as $stderr or File.open(\"debug.log\", \"a\"), or a StringIO " \
        "to collect it, not a String, which names no file, and would be appended every request and response instead"
      # The message of the error raised for a class to parse JSON arrays into that is not a Class
      INVALID_ARRAY_CLASS = "%s must be a Class that JSON.parse builds each array into, such as Array, not %s"
      # The message of the error raised for a class to parse JSON objects into that is not a Class, nor builds a result
      INVALID_OBJECT_CLASS = "%s must be a Class that JSON.parse builds each object into, such as Hash, or respond to " \
        "from_response, as the resource classes of x-resources do, not %s"
      # The message of the error raised for keywords a request takes none of, as the fields of a body given without
      # the braces of a Hash are read
      UNKNOWN_KEYWORDS = "unknown keyword%s: %s; pass a body as a Hash in braces, as %s(%s, %s)"
      # The message of the error raised for a body given as the keyword body, which most HTTP clients take it as
      BODY_KEYWORD = "unknown keyword: :body; pass a body as the second argument, as %s(%s, %s)"
      # The first letter of the name of a class that is named with an, rather than a
      VOWEL = /\A[AEIOU]/
      private_constant :INVALID_COUNT, :INVALID_SECONDS, :INVALID_FINITE_SECONDS, :INVALID_TIMEOUT,
        :INVALID_BASE_URL, :INVALID_HEADERS, :INVALID_HEADER, :INVALID_CALLABLE, :INVALID_DEBUG_OUTPUT, :DEBUG_OUTPUT_STRING,
        :INVALID_ARRAY_CLASS, :INVALID_OBJECT_CLASS, :UNKNOWN_KEYWORDS, :BODY_KEYWORD, :VOWEL

      # Check that a count is an Integer of at least 0
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer] the value
      # @raise [ArgumentError] if the value is not an Integer of at least 0
      # @example Check the retries of a client
      #   X::Core::SettingValidator.count!(:max_retries, 2) # => 2
      def count!(name, value)
        return value if count?(value)

        raise ArgumentError, format(INVALID_COUNT, name, value.inspect)
      end

      # Check that seconds are a real number of at least 0
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer, Float] the value
      # @raise [ArgumentError] if the value is not a real number of at least 0
      # @example Check the longest wait for a rate limit
      #   X::Core::SettingValidator.seconds!(:max_rate_limit_wait, 900) # => 900
      def seconds!(name, value)
        return value if seconds?(value)

        raise ArgumentError, format(INVALID_SECONDS, name, value.inspect)
      end

      # Check that seconds are a finite real number of at least 0
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer, Float] the value
      # @raise [ArgumentError] if the value is not a finite real number of at least 0
      # @example Check the time a connection is kept open
      #   X::Core::SettingValidator.finite_seconds!(:keep_alive_timeout, 30) # => 30
      def finite_seconds!(name, value)
        return value if finite_seconds?(value)

        raise ArgumentError, format(INVALID_FINITE_SECONDS, name, value.inspect)
      end

      # Check that a timeout is finite seconds of at least 0, or nil for no timeout
      #
      # Net::HTTP waits for as long as it takes when a timeout is nil.
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer, Float, nil] the value
      # @raise [ArgumentError] if the value is neither a finite real number of at least 0 nor nil
      # @example Check the timeout for reading a response
      #   X::Core::SettingValidator.timeout!(:read_timeout, 60) # => 60
      def timeout!(name, value)
        return value if value.nil? || finite_seconds?(value)

        raise ArgumentError, format(INVALID_TIMEOUT, name, value.inspect)
      end

      # Check that a base URL is an absolute HTTP or HTTPS URL, with a host
      #
      # An endpoint is appended to the path of the base URL, so a query or a fragment, which would come before the
      # endpoint rather than after it, is refused. So is a user or a password, which Net::HTTP sends with no request,
      # and which the client would reveal in its inspect and in the URI of every error; the error that refuses one
      # leaves the URL out, since the password is a secret.
      #
      # @api private
      # @param value [Object] the base URL
      # @return [String] the base URL
      # @raise [ArgumentError] if the base URL is not a String that is an absolute http or https URL with a host, and
      #   no user, password, query, or fragment
      # @example Check the base URL of the v1.1 API
      #   X::Core::SettingValidator.base_url!("https://api.x.com/1.1/") # => "https://api.x.com/1.1/"
      def base_url!(value)
        raise ArgumentError, BASE_URL_WITH_USERINFO if value.is_a?(String) && value.match?(USERINFO)
        return -value if value.is_a?(String) && http_url?(value)

        raise ArgumentError, format(INVALID_BASE_URL, value.inspect)
      end

      # A frozen copy of a String a caller gave, such as a credential, or nil
      #
      # A credential, token, header, or URL is copied as it is taken, so that the caller that gave it can change
      # neither what is sent nor where.
      #
      # @api private
      # @param value [String, nil] the String, or nil
      # @return [String, nil] a frozen copy of the String, or nil
      # @example Hold a credential
      #   X::Core::SettingValidator.frozen(+"token") # => "token"
      def frozen(value) = value && -value

      # Check that headers are a Hash of header names to String values
      #
      # The headers are returned with each named by a String. Each header must be named with a String or a Symbol. A Symbol names the header its underscores name with
      # hyphens, as :content_type names Content-Type, so that it replaces the header of that name, and is dropped where
      # that header is, rather than being sent beside it as a header no one sends. The error names the class of what is
      # not a Hash, and the name of a header whose name or value is not what a header takes with the class of its
      # value, rather than inspect either, since headers carry credentials, such as an Authorization header.
      #
      # @api private
      # @param value [Object] the headers
      # @return [Hash{String => String}] the headers, each named by a String
      # @raise [ArgumentError] if the headers are not a Hash, or name a header with anything but a String or a
      #   Symbol, or give one anything but a String
      # @example Check headers that name the application
      #   X::Core::SettingValidator.headers!("User-Agent" => "MyApp/1.0") # => {"User-Agent" => "MyApp/1.0"}
      # @example Name a header with a Symbol
      #   X::Core::SettingValidator.headers!(content_type: "text/plain") # => {"content-type" => "text/plain"}
      def headers!(value)
        raise ArgumentError, format(INVALID_HEADERS, named(value.class)) unless value.is_a?(Hash)

        invalid = value.find { |name, header| !header_name?(name) || !header.is_a?(String) }
        invalid ? invalid_header!(*invalid) : value.to_h { |name, header| [header_name(name), -header] }
      end

      # Check that a callable responds to call, or is nil
      #
      # A callable is called only once what it is called for happens, such as a refresh, so one that does not respond
      # to call would raise NoMethodError from inside a request, long after the client was given it. The error names
      # its class rather than inspect it, since a callable can close over credentials.
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the callable, or nil for none
      # @return [#call, nil] the value
      # @raise [ArgumentError] if the value is neither nil nor responds to call
      # @example Check the loader of the tokens a client shares
      #   X::Core::SettingValidator.callable!(:load_tokens, -> { store.load }) # => #<Proc (lambda)>
      def callable!(name, value)
        return value if value.nil? || value.respond_to?(:call)

        raise ArgumentError, format(INVALID_CALLABLE, name, named(value.class))
      end

      # Check that a debug output takes a String with <<, or is nil
      #
      # Net::HTTP writes each request and response to it with <<, once a request is sent, so one that does not respond
      # to << would raise NoMethodError from the first request. A String responds to <<, and would be appended every
      # request, with its Authorization header, where the file it names was meant, so it is refused by name, with
      # what to pass in its place: an IO, or a StringIO to collect what a String was meant to. A Proc and a Method
      # respond to << as well, to compose another callable with, and an Integer to shift it, and each raises
      # TypeError for a String, so each is refused as what does not respond to << is. The error names the class of
      # the value rather than inspect it, as the error of a callable does.
      #
      # @api private
      # @param value [Object] the debug output, or nil for none
      # @return [#<<, nil] the value
      # @raise [ArgumentError] if the value is a String, or is neither nil nor takes a String with <<
      # @example Check the debug output of a client
      #   X::Core::SettingValidator.debug_output!($stderr) # => #<IO:<STDERR>>
      def debug_output!(value)
        raise ArgumentError, DEBUG_OUTPUT_STRING if String === value
        return value if value.nil? || writer?(value)

        raise ArgumentError, format(INVALID_DEBUG_OUTPUT, named(value.class))
      end

      # Check that the class to parse JSON arrays into is a Class
      #
      # JSON.parse builds each array of a body with the new of the class, and appends each element with <<.
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the class
      # @return [Class] the value
      # @raise [ArgumentError] if the value is not a Class
      # @example Check the class a client parses arrays into
      #   X::Core::SettingValidator.array_class!(:default_array_class, Array) # => Array
      def array_class!(name, value)
        return value if value.instance_of?(Class)

        raise ArgumentError, format(INVALID_ARRAY_CLASS, name, value.inspect)
      end

      # Check that the class to parse JSON objects into is a Class, or builds a result
      #
      # JSON.parse builds each object of a body with the new of a class, and sets each member with []=, unless it
      # responds to from_response, which builds the result from the whole body instead; see {Client}.
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the class, or what builds the result of a request
      # @return [Class, #from_response] the value
      # @raise [ArgumentError] if the value is neither a Class nor responds to from_response
      # @example Check the class a client parses objects into
      #   X::Core::SettingValidator.object_class!(:default_object_class, Hash) # => Hash
      def object_class!(name, value)
        return value if value.instance_of?(Class) || value.respond_to?(:from_response)

        raise ArgumentError, format(INVALID_OBJECT_CLASS, name, value.inspect)
      end

      # Refuse the keywords a request takes none of, saying how to pass them as its body
      #
      # A body is a positional argument, so its fields given without the braces of a Hash, as in
      # post("tweets", text: "Hello"), are read as keywords, which Ruby would refuse as unknown without saying that
      # the body is passed in braces. A body given as the keyword body alone, which most HTTP clients take it as, is
      # shown as the second argument instead, since body in braces would be sent as a field of the body. Beside other
      # keywords, body is taken for a field among them.
      #
      # @api private
      # @param http_method [Symbol] the method of the request, such as :post
      # @param endpoint [String] the endpoint of the request
      # @param keywords [Hash{Symbol, String => Object}] the keywords the request takes none of
      # @return [void]
      # @raise [ArgumentError] if there are any such keywords
      # @example Refuse the fields of a body given without braces
      #   X::Core::SettingValidator.no_unknown_keywords!(:post, "tweets", {text: "Hello"})
      #   # raises ArgumentError: unknown keyword: :text; pass a body as a Hash in braces, as post("tweets", {text: "Hello"})
      # @example Refuse a body given as a keyword
      #   X::Core::SettingValidator.no_unknown_keywords!(:post, "tweets", {body: {text: "Hello"}})
      #   # raises ArgumentError: unknown keyword: :body; pass a body as the second argument, as post("tweets", {text: "Hello"})
      def no_unknown_keywords!(http_method, endpoint, keywords)
        return if keywords.empty?
        raise ArgumentError, format(BODY_KEYWORD, http_method, endpoint.inspect, keywords.fetch(:body).inspect) if keywords.keys.eql?([:body])

        names = keywords.keys.map(&:inspect).join(", ")
        raise ArgumentError, format(UNKNOWN_KEYWORDS, ("s" if keywords.size > 1), names, http_method, endpoint.inspect, keywords)
      end

      # Check the classes a request parses its response into, before the request is sent
      #
      # @api private
      # @param array_class [Object] the class to parse JSON arrays into
      # @param object_class [Object] the class to parse JSON objects into, or what builds the result of the request
      # @return [void]
      # @raise [ArgumentError] if the array class is not a Class, or the object class is neither a Class nor responds
      #   to from_response
      # @example Check the classes of a request
      #   X::Core::SettingValidator.parsing_classes!(array_class: Array, object_class: X::User)
      def parsing_classes!(array_class:, object_class:)
        array_class!(:array_class, array_class)
        object_class!(:object_class, object_class)
      end

      private

      # Raise for a header whose name or value is not what a header takes
      # @api private
      # @param name [Object] the name of the header
      # @param header [Object] the value of the header
      # @return [void]
      # @raise [ArgumentError] always
      def invalid_header!(name, header)
        raise ArgumentError, format(INVALID_HEADER, name: header_name?(name) ? name.inspect : named(name.class), value: named(header.class))
      end

      # A class named with its article, as an error names the class of what it refuses
      # @api private
      # @param klass [Class] the class
      # @return [String] the name of the class after a, or an for a name that begins with a vowel, as an Integer
      def named(klass) = "#{klass.to_s.match?(VOWEL) ? "an" : "a"} #{klass}"

      # Check whether a value takes a String with <<, as an IO does
      #
      # The << of a Proc or a Method composes it with another callable, and the << of an Integer shifts it, rather
      # than write to it, and each raises TypeError for a String.
      #
      # @api private
      # @param value [Object] the value
      # @return [Boolean] true if the value responds to <<, and is not a Proc, a Method, or an Integer
      def writer?(value) = value.respond_to?(:<<) && !(Proc === value) && !(Method === value) && !(Integer === value)

      # The String a header is named by
      #
      # A String names itself, and a Symbol the header its underscores name with hyphens.
      #
      # @api private
      # @param name [String, Symbol] the name of the header
      # @return [String] the name of the header
      def header_name(name) = name.instance_of?(Symbol) ? name.name.tr("_", "-") : name

      # Check whether a value names a header, as a String or a Symbol does
      # @api private
      # @param value [Object] the value
      # @return [Boolean] true if the value is a String or a Symbol
      def header_name?(value) = value.is_a?(String) || value.instance_of?(Symbol)

      # Check whether a String is an absolute HTTP or HTTPS URL fit to be a base URL
      # @api private
      # @param value [String] the URL
      # @return [Boolean] true if the URL is an absolute http or https URL with a host, and no query or fragment
      def http_url?(value)
        uri = URI(value)
        uri.is_a?(URI::HTTP) && !uri.host.to_s.empty? && uri.query.nil? && uri.fragment.nil?
      rescue URI::InvalidURIError
        false
      end

      # Check whether a value is an Integer of at least 0
      # @api private
      # @param value [Object] the value
      # @return [Boolean] true if the value is an Integer of at least 0
      def count?(value) = value.instance_of?(Integer) && !value.negative?

      # Check whether a value is a real number of at least 0
      #
      # Float::NAN is neither negative nor at least 0, and a wait compared with it is never longer, so it is compared
      # with 0 rather than asked whether it is negative, which would let it pass as a limit that never applies.
      #
      # @api private
      # @param value [Object] the value
      # @return [Boolean] true if the value is a real number of at least 0
      def seconds?(value) = value.is_a?(Numeric) && value.real? && value >= 0

      # Check whether a value is a finite real number of at least 0
      # @api private
      # @param value [Object] the value
      # @return [Boolean] true if the value is a finite real number of at least 0
      def finite_seconds?(value) = seconds?(value) && value.finite?
    end
    private_constant :SettingValidator
  end
end
