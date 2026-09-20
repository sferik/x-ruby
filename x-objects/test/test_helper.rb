$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

unless $PROGRAM_NAME.include?("mutant")
  require "simplecov"

  SimpleCov.start "strict"
end

require "json"
require "minitest/autorun"
require "minitest/mock"
require "mutant/minitest/coverage"
require "uri"
require "x/objects"

# A client double for the object layer that records requests and returns canned responses
class FakeClient
  include X::Objects::API

  # The object layer must always ask for plain hashes and arrays
  JSON_CLASSES = {array_class: Array, object_class: Hash}.freeze

  attr_reader :requests

  def initialize(responses = {})
    @responses = responses
    @requests = []
    @mutex = Mutex.new
  end

  def get(endpoint, **options)
    respond(:get, endpoint, nil, options)
  end

  def post(endpoint, body = nil, **options)
    respond(:post, endpoint, body, options)
  end

  def delete(endpoint, **options)
    respond(:delete, endpoint, nil, options)
  end

  def put(endpoint, body = nil, **options)
    respond(:put, endpoint, body, options)
  end

  def stub(method, path, response)
    @responses[[method, path]] = response
    self
  end

  def paths
    requests.map { |request| request.fetch(:path) }
  end

  def queries
    requests.map { |request| request.fetch(:query) }
  end

  private

  def respond(method, endpoint, body, options)
    raise ArgumentError, "expected #{JSON_CLASSES} but got #{options}" unless options.eql?(JSON_CLASSES)

    uri = URI.parse(endpoint)
    query = record(method, uri, body)
    response = @responses.fetch([method, uri.path]) { raise KeyError, "unstubbed #{method} #{uri.path}" }
    response.respond_to?(:call) ? response.call(query, encoded(body)) : response
  end

  # Record a request as it was sent, and give the query it carried
  def record(method, uri, body)
    query = URI.decode_www_form(uri.query.to_s).to_h
    @mutex.synchronize { @requests << {method:, path: uri.path, query:, body: encoded(body)} }
    query
  end

  # The body as X::Client sends it: a String as it is, and anything else, such as a Hash, as JSON
  def encoded(body)
    return body if body.nil? || body.is_a?(String)

    JSON.generate(body)
  end
end
