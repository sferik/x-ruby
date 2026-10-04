# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A response keeps the body it parsed apart from its own state, so one that was frozen counts its resources as any
  # other does, and a dup or clone of it parses no body again, since the body they hold is one
  class ResponseFrozenTest < Minitest::Test
    cover Response
    cover Core.const_get(:ResponseHeaders)

    URI_ME = URI("https://api.x.com/2/users/me")

    def test_a_frozen_response_counts_its_resources
      response = Response.new(http_method: :get, uri: URI_ME, status: 200, body: '{"data":[{"id":"1"}],"includes":{"users":[{"id":"2"}]}}').freeze

      assert_equal [{"data" => 1, "users" => 1}, 2], [response.resource_counts, response.resource_count]
    end

    def test_a_frozen_response_without_resources_counts_none
      response = Response.new(http_method: :get, uri: URI("https://api.x.com/2/users"), status: 200, body: "{}").freeze

      assert_equal [{"data" => 0}, 0], [response.resource_counts, response.resource_count]
    end

    def test_the_body_of_a_frozen_response_is_parsed_once
      response = summarize(Net::HTTPOK, body: {data: [{id: "1"}, {id: "2"}]}.to_json).freeze
      parses = 0
      parse = lambda do |_json|
        parses += 1
        {"data" => [{"id" => "1"}, {"id" => "2"}]}
      end
      counts = JSON.stub(:parse, parse) { [response.resource_counts, response.resource_count, response.resource_counts] }

      assert_equal [1, [{"data" => 2}, 2, {"data" => 2}]], [parses, counts]
    end

    def test_a_frozen_response_reads_everything_else_as_any_other_does
      response = Response.new(http_method: :get, uri: URI_ME, status: 200, headers: {"x-rate-limit-limit" => "75", "x-rate-limit-remaining" => "74", "x-rate-limit-reset" => "1789505092"}, body: "{}").freeze

      assert_equal [200, true, "{}", "75", 74, [74]],
        [response.status, response.success?, response.body, response.headers["x-rate-limit-limit"], response.rate_limit.remaining, response.rate_limits.map(&:remaining)]
    end

    def test_a_response_frozen_deeply_counts_its_resources
      response = Ractor.make_shareable(Response.new(http_method: :get, uri: URI_ME, status: 200, body: '{"data":[{"id":"1"}],"includes":{"users":[{"id":"2"}]}}'))

      assert_equal [{"data" => 1, "users" => 1}, 2, {"data" => 1, "users" => 1}], [response.resource_counts, response.resource_count, response.resource_counts]
    end

    def test_a_response_frozen_deeply_once_it_was_counted_parses_no_body_again
      response = summarize(Net::HTTPOK, body: {data: [{id: "1"}, {id: "2"}]}.to_json)
      counted = response.resource_counts
      Ractor.make_shareable(response)

      assert_equal [counted, 2], JSON.stub(:parse, ->(_json) { flunk "The body was parsed again" }) { [response.resource_counts, response.resource_count] }
    end

    def test_a_response_frozen_deeply_reads_everything_else_as_any_other_does
      response = Ractor.make_shareable(Response.new(http_method: :get, uri: URI_ME, status: 200, headers: {"x-rate-limit-limit" => "75"}, body: "{}"))

      assert_equal [200, true, "{}", "75", URI_ME], [response.status, response.success?, response.body, response.headers["x-rate-limit-limit"], response.uri]
    end

    def test_a_copy_counts_the_resources_of_the_response
      response = summarize(Net::HTTPOK, body: {data: [{id: "1"}, {id: "2"}]}.to_json)

      %i[dup clone].each { |copy| assert_equal [{"data" => 2}, 2], response.public_send(copy).then { |copied| [copied.resource_counts, copied.resource_count] } }
    end

    def test_a_copy_of_a_frozen_response_counts_its_resources
      response = summarize(Net::HTTPOK, body: {data: {id: "1"}}.to_json).freeze

      %i[dup clone].each { |copy| assert_equal({"data" => 1}, response.public_send(copy).resource_counts) }
    end

    def test_a_copy_does_not_parse_the_body_the_response_parsed
      response = summarize(Net::HTTPOK, body: {data: [{id: "1"}, {id: "2"}]}.to_json)
      counted = response.resource_counts
      copies = JSON.stub(:parse, ->(_json) { flunk "The body was parsed again" }) { [response.dup.resource_counts, response.clone.resource_counts] }

      assert_equal [counted, counted], copies
    end

    private

    def summarize(klass, body:)
      http_response = klass.new("1.1", "200", "")
      http_response.instance_variable_set(:@body, body)
      http_response.instance_variable_set(:@read, true)
      Response.new(http_response:, http_method: :get, uri: URI_ME)
    end
  end
end
