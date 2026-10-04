# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The examples run as written on the data they describe and on ordinary data they do not, such as a post they do not
  # match, a message with no links, or a user with no bookmark folders
  class ExamplesTest < Minitest::Test
    def example(file, title)
      source = File.read(File.expand_path("../../../lib/x/resources/#{file}", __dir__))
      indent, code = source.match(/^(\s*#\s*)@example #{Regexp.escape(title)}\n((?:\1  .*\n)+)/).captures
      code.gsub(/^#{Regexp.escape(indent)}  /, "")
    end

    def run_example(file, title, **locals)
      code = example(file, title)
      result = nil
      output = capture_io { result = binding.tap { |b| locals.each { |name, value| b.local_variable_set(name, value) } }.eval(code) }
      [*output, result]
    end

    def test_the_examples_matching_a_post_print_for_a_post_they_match
      post = Post.new({"id" => "1", "author_id" => "7505382", "public_metrics" => {"retweet_count" => 100}})

      assert_equal ["by sferik\n", "", nil], run_example("identity.rb", "Match a post by its author", post:)
      assert_equal ["widely reposted\n", "", nil], run_example("identity.rb", "Match a post by a name from before posts were posts", post:)
    end

    def test_the_examples_matching_a_post_do_nothing_for_a_post_they_do_not_match
      post = Post.new({"id" => "1", "author_id" => "12", "public_metrics" => {"retweet_count" => 3}})

      assert_equal ["", "", nil], run_example("identity.rb", "Match a post by its author", post:)
      assert_equal ["", "", nil], run_example("identity.rb", "Match a post by a name from before posts were posts", post:)
    end

    def test_the_example_warning_near_the_cap_warns_only_near_the_cap
      title = "Warn when the project has read nine tenths of its cap"

      assert_equal ["", "near the cap\n", nil], run_example("post_usage.rb", title, usage: PostUsage.new({"project_usage" => "2700000", "project_cap" => "3000000"}))
      assert_equal ["", "", nil], run_example("post_usage.rb", title, usage: PostUsage.new({"project_usage" => "1234", "project_cap" => "3000000"}))
    end

    def test_the_example_getting_the_urls_of_a_message_gets_none_for_a_message_with_no_links
      title = "Get the URLs of a message"
      urls = [{"url" => "https://t.co/x"}]

      assert_equal ["", "", urls], run_example("direct_message.rb", title, message: DirectMessage.new({"id" => "1", "entities" => {"urls" => urls}}))
      assert_equal ["", "", nil], run_example("direct_message.rb", title, message: DirectMessage.new({"id" => "1", "entities" => {"mentions" => []}}))
    end

    def test_the_example_printing_a_bookmark_folder_prints_its_posts
      client = FakeClient.new.stub(:get, "users/me", {"data" => {"id" => "1"}})
      client.stub(:get, "users/1/bookmarks/folders", {"data" => [{"id" => "2", "name" => "Ruby"}]})
      client.stub(:get, "users/1/bookmarks/folders/2", {"data" => [{"id" => "10"}]})
      client.stub(:get, "tweets", {"data" => [{"id" => "10", "text" => "in the folder"}]})

      assert_equal "in the folder\n", run_example("user_collections.rb", "Print the posts of the first bookmark folder", client:).first
    end

    def test_the_example_printing_a_bookmark_folder_prints_nothing_for_a_user_with_no_folders
      client = FakeClient.new.stub(:get, "users/me", {"data" => {"id" => "1"}}).stub(:get, "users/1/bookmarks/folders", {"data" => []})

      assert_equal ["", "", nil], run_example("user_collections.rb", "Print the posts of the first bookmark folder", client:)
      assert_equal ["users/me", "users/1/bookmarks/folders"], client.paths
    end

    def test_the_example_paging_through_the_archive_asks_only_for_fields_a_post_has
      client = FakeClient.new.stub(:get, "tweets/search/all", {"data" => []})
      run_example("post_search.rb", "Page through every post about Ruby 500 at a time, without context annotations", client:).last.first
      fields = client.queries.first.fetch("post.fields").split(",")

      assert_empty fields - Post::FIELDS
    end
  end
end
