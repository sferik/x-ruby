require_relative "../../test_helper"

module X
  class ListUpdateTest < Minitest::Test
    cover List

    def setup
      @client = FakeClient.new
      @list = List.new({"id" => "1"}, client: @client)
    end

    def test_update
      @client.stub(:put, "lists/1", {"data" => {"updated" => true}})

      assert List.update(List.new({"id" => "1"}), client: @client, name: "Rubyists", private: true)
      assert_equal [{method: :put, path: "lists/1", query: {}, body: {name: "Rubyists", private: true}.to_json}], @client.requests
    end

    def test_update_reports_only_true
      @client.stub(:put, "lists/1", {"data" => {"updated" => "yes"}})

      refute List.update(1, client: @client, description: "Ruby")
      @client.stub(:put, "lists/1", nil)

      refute List.update(1, client: @client, description: "Ruby")
    end

    def test_update_this_list
      @client.stub(:put, "lists/1", {"data" => {"updated" => true}})

      assert_same true, @list.update(description: "People who write Ruby")
      assert_equal [{description: "People who write Ruby"}.to_json], @client.requests.map { |request| request[:body] }
    end
  end
end
