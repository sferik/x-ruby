# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A response that holds something other than an object where the API documents a resource, or the data of a write,
  # or a String, raises InvalidAttribute where it is read, as every value that cannot be read does
  class InvalidShapeResponseTest < Minitest::Test
    cover Resources.const_get(:Shape)
    cover Resources.const_get(:UserFinders)
    cover Resources.const_get(:Utils)
    cover Resource
    cover List
    cover Post
    cover User

    def test_a_resource_in_a_list_that_is_not_an_object_raises
      [nil, 1, []].each do |entry|
        assert_raises(InvalidAttribute) { User.from_response({"data" => [entry]}, client: nil) }
      end
    end

    def test_the_data_of_a_write_that_is_not_an_object_raises
      [[], "x", 7].each do |data|
        client = FakeClient.new.stub(:delete, "lists/1", {"data" => data})

        assert_equal "the data of the response cannot be read from #{data.inspect}", assert_raises(InvalidAttribute) { List.delete(1, client:) }.message
      end
    end

    def test_a_write_whose_response_holds_no_data_is_not_done
      [{}, nil].each { |body| assert_same false, List.delete(1, client: FakeClient.new.stub(:delete, "lists/1", body)) }
    end

    def test_a_username_that_is_not_a_string_raises_from_a_lookup_of_several
      [-1, 2, true].each do |username|
        client = FakeClient.new.stub(:get, "users", {"data" => [{"id" => "2", "username" => "a"}, {"id" => "3", "username" => username}]})

        assert_equal "X::User#username cannot be read from #{username}", assert_raises(InvalidAttribute) { User.find_all([2, 3], client:) }.message
      end
    end

    def test_a_lookup_of_several_matches_users_without_a_username_by_identifier
      client = FakeClient.new.stub(:get, "users", {"data" => [{"id" => "3"}, {"id" => "2", "username" => "a"}]})

      assert_equal [2, 3], User.find_all([2, 3], client:).map(&:id)
    end

    def test_text_that_is_not_a_string_raises_from_the_expanded_text
      [5, false].each do |text|
        error = assert_raises(InvalidAttribute) { Post.new({"id" => "1", "text" => text}).expanded_text }

        assert_equal "X::Post#expanded_text cannot be read from #{text}", error.message
      end
    end

    def test_a_username_that_is_not_a_string_raises_from_the_permalink
      user = User.new({"id" => "2", "username" => ["a"]})

      assert_equal "X::User#permalink cannot be read from [\"a\"]", assert_raises(InvalidAttribute) { user.permalink }.message
      assert_raises(InvalidAttribute) { user.uri }
      assert_raises(InvalidAttribute) { User.new({"id" => "2", "username" => false}).permalink }
    end

    def test_an_author_username_that_is_not_a_string_raises_from_the_permalink_of_a_post
      body = {"data" => {"id" => "1", "author_id" => "2"}, "includes" => {"users" => [{"id" => "2", "username" => 7.5}]}}
      post = Post.from_response(body, client: nil)

      assert_equal "X::Post#permalink cannot be read from 7.5", assert_raises(InvalidAttribute) { post.permalink }.message
    end

    def test_a_username_that_is_a_string_or_none_names_the_permalink
      assert_equal %w[https://x.com/a https://x.com/i/user/2],
        [User.new({"id" => "2", "username" => "a"}).permalink, User.new({"id" => "2"}).permalink]
    end
  end
end
