# frozen_string_literal: true

require "net/http"
require_relative "setting_validator"

module X
  module Core
    # The HTTP response of an error or a summary built by hand, from its status, headers, and body
    #
    # Internal to x-core: HTTPError, InvalidResponse, and Response are built from the Net::HTTP response a client
    # received, or, so that code that rescues one, or an on_response hook, can be tested without building one, from
    # the status, headers, and body of a response, which this builds the Net::HTTP response of.
    #
    # @api private
    module BuiltResponse
      extend self

      # The message of the error raised for a status that is not one HTTP defines
      INVALID_STATUS = "status must be an Integer from 100 to 599, not %s"
      private_constant :INVALID_STATUS
      # The message of the error raised for a response given beside what one is built of, or for neither
      RESPONSE_OR_STATUS = "Pass the http_response:, or the status:, headers:, and body: one is built of, and not both"
      private_constant :RESPONSE_OR_STATUS
      # The statuses HTTP defines
      STATUSES = 100..599
      private_constant :STATUSES

      # The HTTP response given, or the one built of a status, headers, and body
      #
      # @api private
      # @param http_response [Net::HTTPResponse, nil] the HTTP response, or nil to build one
      # @param status [Integer, nil] the status of the response to build, or nil for the one given
      # @param headers [Hash{String => String}, nil] the headers of the response to build, or nil for none
      # @param body [String, nil] the body of the response to build, or nil for none
      # @return [Net::HTTPResponse] the HTTP response
      # @raise [ArgumentError] if a response is given beside a status, headers, or a body, or neither a response nor a
      #   status is given, or the status is not one HTTP defines, or the headers are not a Hash of names to values
      # @example Build a response the API refused a request with
      #   X::Core::BuiltResponse.of(nil, status: 404, headers: nil, body: "{}") # => #<Net::HTTPNotFound 404 Not Found>
      def of(http_response, status:, headers:, body:)
        return build(status, headers || {}, body) if http_response.nil? && !status.nil?
        raise ArgumentError, RESPONSE_OR_STATUS unless http_response && [status, headers, body].none?

        http_response
      end

      private

      # Build the HTTP response of a status, headers, and body
      #
      # Its body is tagged UTF-8, as the body of a response the client reads is.
      #
      # @api private
      # @param status [Integer] the status
      # @param headers [Hash{String => String}] the headers
      # @param body [String, nil] the body
      # @return [Net::HTTPResponse] the HTTP response
      # @raise [ArgumentError] if the status is not one HTTP defines, or the headers are not a Hash of names to values
      def build(status, headers, body)
        response_class = response_class_of(status)
        response_class.new("1.1", status.to_s, reason_of(response_class)).tap do |response|
          SettingValidator.headers!(headers).each { |name, value| response[name] = value }
          response.body = body.dup&.force_encoding(Encoding::UTF_8)
          response.instance_variable_set(:@read, true)
        end
      end

      # The class Net::HTTP reads a response of a status as
      #
      # It is the class of the status, such as Net::HTTPNotFound, or, for a status Net::HTTP names no class of, the
      # class of its kind of status, such as Net::HTTPClientError for a 4xx.
      #
      # @api private
      # @param status [Integer] the status
      # @return [Class] the class
      # @raise [ArgumentError] if the status is not one HTTP defines
      def response_class_of(status)
        raise ArgumentError, format(INVALID_STATUS, status.inspect) unless status.instance_of?(Integer) && STATUSES.cover?(status)

        code = status.to_s
        Net::HTTPResponse::CODE_TO_OBJ.fetch(code) { Net::HTTPResponse::CODE_CLASS_TO_OBJ.fetch(code[0]) }
      end

      # The reason phrase of the status of a Net::HTTP response class
      #
      # @api private
      # @param response_class [Class] the class, such as Net::HTTPNotFound
      # @return [String] the reason phrase, such as "Not Found"
      def reason_of(response_class)
        name = response_class.name #: String
        name.delete_prefix("Net::HTTP").gsub(/(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])/, " ")
      end
    end
    private_constant :BuiltResponse
  end
end
