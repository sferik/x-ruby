require "net/http"
require "uri"
require_relative "version"

module X
  # Creates HTTP requests
  class RequestBuilder
    HTTP_METHODS = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      put: Net::HTTP::Put,
      delete: Net::HTTP::Delete
    }.freeze
    DEFAULT_CONTENT_TYPE = "application/json; charset=utf-8".freeze
    DEFAULT_USER_AGENT = "X-Client/#{VERSION} Ruby/#{RUBY_VERSION}".freeze
    AUTHORIZATION_HEADER = "Authorization".freeze
    CONTENT_TYPE_HEADER = "Content-Type".freeze
    USER_AGENT_HEADER = "User-Agent".freeze

    attr_accessor :content_type, :user_agent

    def initialize(content_type: DEFAULT_CONTENT_TYPE, user_agent: DEFAULT_USER_AGENT)
      @content_type = content_type
      @user_agent = user_agent
    end

    def build(authenticator, http_method, url, body: nil)
      request = create_request(http_method, url, body)
      add_authorization(request, authenticator)
      add_content_type(request)
      add_user_agent(request)
      request
    end

    private

    def create_request(http_method, url, body)
      http_method_class = HTTP_METHODS[http_method]

      raise ArgumentError, "Unsupported HTTP method: #{http_method}" unless http_method_class

      request = http_method_class.new(url)
      request.body = body if body && http_method != :get
      request
    end

    def add_authorization(request, authenticator)
      request.add_field(AUTHORIZATION_HEADER, authenticator.header(request))
    end

    def add_content_type(request)
      request.add_field(CONTENT_TYPE_HEADER, content_type) if content_type
    end

    def add_user_agent(request)
      request.add_field(USER_AGENT_HEADER, user_agent) if user_agent
    end
  end
end
