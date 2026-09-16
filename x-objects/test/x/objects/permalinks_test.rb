require_relative "../../test_helper"

module X
  class PermalinksTest < Minitest::Test
    cover User
    cover X::Objects::UserFinders
    cover Post
    cover List
    cover Community

    def test_user_permalink
      assert_equal "https://x.com/sferik", User.new({"id" => "1", "username" => "sferik"}).permalink
      assert_equal "https://x.com/i/user/1", User.new({"id" => "1"}).permalink
    end

    def test_post_url
      includes = Objects::Includes.new({"users" => [{"id" => "9", "username" => "sferik"}]})

      assert_equal "https://x.com/sferik/status/1", Post.new({"id" => "1", "author_id" => "9"}, includes:).permalink
      assert_equal "https://x.com/i/status/1", Post.new({"id" => "1", "author_id" => "8"}, includes:).permalink
      assert_equal "https://x.com/i/status/1", Post.new({"id" => "1"}).permalink
    end

    def test_list_url
      assert_equal "https://x.com/i/lists/1", List.new({"id" => "1"}).permalink
    end

    def test_community_url
      assert_equal "https://x.com/i/communities/7", Community.new({"id" => "7"}).permalink
    end

    def test_a_permalink_is_also_a_uri
      includes = Objects::Includes.new({"users" => [{"id" => "9", "username" => "sferik"}]})
      resources = [User.new({"id" => "1", "username" => "sferik"}), Post.new({"id" => "1", "author_id" => "9"}, includes:),
        List.new({"id" => "1"}), Community.new({"id" => "7"})]

      assert_equal ["https://x.com/sferik", "https://x.com/sferik/status/1", "https://x.com/i/lists/1",
        "https://x.com/i/communities/7"], resources.map { |resource| resource.uri.to_s }
      assert_equal [URI::HTTPS] * 4, resources.map { |resource| resource.uri.class }
    end
  end
end
