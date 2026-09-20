require_relative "../../test_helper"

module X
  class ResponseTest < Minitest::Test
    cover Response

    URI_ME = URI("https://api.x.com/2/users/me")

    def test_request_details
      response = summarize(Net::HTTPOK)

      assert_equal [:get, URI_ME, 200], [response.http_method, response.uri, response.status]
      assert_predicate response, :success?
    end

    def test_a_failed_request
      response = summarize(Net::HTTPNotFound, code: "404")

      assert_equal 404, response.status
      refute_predicate response, :success?
    end

    def test_rate_limits
      response = summarize(Net::HTTPOK, headers: {"x-rate-limit-limit" => "75", "x-rate-limit-remaining" => "74", "x-rate-limit-reset" => "1789505092",
                                                  "x-user-limit-24hour-limit" => "100", "x-user-limit-24hour-remaining" => "3", "x-user-limit-24hour-reset" => "1789500000"})

      assert_equal [["rate-limit", 74], ["user-limit-24hour", 3]], response.rate_limits.map { |limit| [limit.type, limit.remaining] }
      assert_equal [75, "rate-limit"], [response.rate_limit.limit, response.rate_limit.type]
    end

    def test_a_daily_limit_alone_has_no_rate_limit
      response = summarize(Net::HTTPOK, headers: {"x-app-limit-24hour-limit" => "10", "x-app-limit-24hour-remaining" => "9", "x-app-limit-24hour-reset" => "1"})

      assert_nil response.rate_limit
      assert_equal ["app-limit-24hour"], response.rate_limits.map(&:type)
    end

    def test_no_rate_limits
      assert_empty summarize(Net::HTTPOK).rate_limits
      assert_nil summarize(Net::HTTPOK).rate_limit
    end

    def test_resource_counts_of_an_object_with_includes
      response = summarize(Net::HTTPOK, body: {data: {id: "1", name: "Erik", username: "sferik"}, includes: {posts: [{id: "2"}], users: [{id: "3"}, {id: "4"}]}}.to_json)

      assert_equal({"data" => 1, "posts" => 1, "users" => 2}, response.resource_counts)
      assert_equal 4, response.resource_count
    end

    def test_resource_counts_of_a_collection
      response = summarize(Net::HTTPOK, body: {data: [{id: "1"}, {id: "2"}], meta: {result_count: 2}}.to_json)

      assert_equal({"data" => 2}, response.resource_counts)
      assert_equal({"data" => 0, "users" => 0}, summarize(Net::HTTPOK, body: {data: nil, includes: {users: nil}}.to_json).resource_counts)
    end

    def test_resource_counts_without_resources
      assert_equal({"data" => 0}, summarize(Net::HTTPOK, body: {errors: [{title: "Not Found Error"}]}.to_json).resource_counts)
      assert_equal({"data" => 0}, summarize(Net::HTTPNoContent, body: nil).resource_counts)
      assert_equal({"data" => 0}, summarize(Net::HTTPOK, body: "not json").resource_counts)
      assert_equal({"data" => 0}, summarize(Net::HTTPOK, body: "[1, 2]").resource_counts)
      assert_equal 0, summarize(Net::HTTPOK, body: "[1, 2]").resource_count
    end

    def test_the_body_is_parsed_once_however_many_counts_are_read
      response = summarize(Net::HTTPOK, body: {data: [{id: "1"}, {id: "2"}]}.to_json)
      parses = 0
      parse = lambda do |_json|
        parses += 1
        {"data" => [{"id" => "1"}, {"id" => "2"}]}
      end
      counts = JSON.stub(:parse, parse) { [response.resource_counts, response.resource_count, response.resource_counts] }

      assert_equal 1, parses
      assert_equal [{"data" => 2}, 2, {"data" => 2}], counts
    end

    def test_a_part_of_the_body
      http_response = summarize(Net::HTTPOK, body: '{"data":[{"id":"1"},{"id":"2"}]}').http_response
      response = Response.new(:get, URI_ME, http_response, body: '{"data":{"id":"1"}}')

      assert_equal '{"data":{"id":"1"}}', response.body
      assert_equal 1, response.resource_count
      assert_equal '{"data":[{"id":"1"},{"id":"2"}]}', Response.new(:get, URI_ME, http_response).body
    end

    private

    def summarize(klass, code: "200", headers: {}, body: "{}")
      http_response = klass.new("1.1", code, "")
      headers.each { |name, value| http_response[name] = value }
      http_response.instance_variable_set(:@body, body)
      http_response.instance_variable_set(:@read, true)
      Response.new(:get, URI_ME, http_response)
    end
  end
end
