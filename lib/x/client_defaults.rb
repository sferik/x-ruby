require_relative "version"

module X
  module ClientDefaults
    DEFAULT_BASE_URL = "https://api.twitter.com/2/".freeze
    DEFAULT_CONTENT_TYPE = "application/json; charset=utf-8".freeze
    DEFAULT_ARRAY_CLASS = Array
    DEFAULT_OBJECT_CLASS = Hash
    DEFAULT_OPEN_TIMEOUT = 60 # seconds
    DEFAULT_READ_TIMEOUT = 60 # seconds
    DEFAULT_USER_AGENT = "X-Client/#{VERSION} Ruby/#{RUBY_VERSION}".freeze
  end
end
