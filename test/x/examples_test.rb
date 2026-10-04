# frozen_string_literal: true

require "fileutils"
require "stringio"
require "tmpdir"
require_relative "../test_helper"

module X
  # Runs each example in examples/ against stubbed responses, so that an example the API has drifted from fails
  class ExamplesTest < Minitest::Test
    EXAMPLES_DIR = File.expand_path("../../examples", __dir__)
    BASE = "https://api.x.com/2/"
    V1_BASE = "https://api.x.com/1.1/"
    # The files the examples read, by the path each names, beginning with the bytes their type is told by
    MEDIA = {
      "path/to/your/media.mp4" => "\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom",
      "path/to/your/media.jpg" => "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00",
      "path/to/your/avatar.png" => "\x89PNG\r\n\x1A\n\x00\x00\x00\x0DIHDR",
      "path/to/your/banner.png" => "\x89PNG\r\n\x1A\n\x00\x00\x00\x0DIHDR"
    }.freeze
    # Raised by the stream when the example reconnects, which it does without end, to end it
    StreamEnded = Class.new(StandardError)

    def test_every_example_has_a_smoke_test
      examples = Dir.children(EXAMPLES_DIR).map { |file| File.basename(file, ".rb") }
      tested = public_methods.grep(/\Atest_the_(\w+)_example_runs\z/) { $1 }

      assert_equal examples.sort, tested.sort, "Each example in examples/ needs a test_the_<name>_example_runs"
    end

    def test_the_chunked_media_upload_example_runs
      stub_path(:post, "media/upload/initialize", {data: {id: "7", media_key: "7_7", expires_after_secs: 86_400}})
      stub_path(:post, "media/upload/7/append", {})
      stub_path(:post, "media/upload/7/finalize", {data: {id: "7", media_key: "7_7"}})
      stub_path(:get, "media/upload", {data: {id: "7", media_key: "7_7", processing_info: {state: "succeeded"}}})
      stub_path(:post, "tweets", {data: {id: "9", text: "Posting media from @gem!"}})

      assert_equal "9\n", run_example("chunked_media_upload")
      assert_requested :post, "#{BASE}media/upload/initialize", body: {media_type: "video/mp4", media_category: "tweet_video", total_bytes: 24}.to_json
      assert_requested :post, "#{BASE}media/upload/7/finalize"
      assert_requested :get, "#{BASE}media/upload?command=STATUS&media_id=7"
      assert_requested :post, "#{BASE}tweets", body: {text: "Posting media from @gem!", media: {media_ids: ["7"]}}.to_json
    end

    def test_the_filtered_stream_example_runs
      stub_stream_rules
      stub_stream({data: {id: "5", text: "Hello, Ruby"}, includes: {users: [{id: "1", username: "sferik"}]}}, {data: {id: "6", text: "Hi"}})

      assert_raises(StreamEnded) { run_example("filtered_stream") }
      assert_match(/^Deleted 1 rule\(s\)$/, @output.string)
      assert_match(/^@sferik: Hello, Ruby\n@: Hi$/, @output.string)
      assert_requested :post, "#{BASE}tweets/search/stream/rules", body: {add: [{value: "ruby lang", tag: "ruby"}, {value: "#opensource", tag: "opensource"}]}.to_json
      assert_requested :get, "#{BASE}tweets/search/stream?expansions=author_id&tweet.fields=created_at", times: 2
    end

    def test_the_followers_example_runs
      stub_path(:get, "users/by/username/sferik", {data: {id: "1", username: "sferik", public_metrics: {followers_count: 2}}})
      stub_path(:get, "users/1/followers", {data: [follower("2", "alice"), follower("3", "bob")], meta: {result_count: 2}})
      stub_path(:get, "users/1/tweets", {data: [{id: "10", text: "Hello", author_id: "1"}], includes: {users: [{id: "1", username: "sferik"}]}})

      assert_equal "alice: 5 followers\nbob: 5 followers\n2\n2\nsferik: Hello\n", run_example("followers")
      assert_requested :get, path_pattern("users/1/followers"), times: 1
    end

    def test_the_pagination_example_runs
      stub_path(:get, "users/by/username/sferik", {data: {id: "1", username: "sferik"}})
      stub_path(:get, "users/1/followers", {data: [{id: "2"}], meta: {next_token: "NEXT"}})
      stub_path(:get, "users/1/followers", {data: [{id: "3"}], meta: {result_count: 1}}).with(query: hash_including(pagination_token: "NEXT"))

      assert_equal "2\n2\n", run_example("pagination")
      assert_requested :get, path_pattern("users/1/followers"), times: 4
    end

    def test_the_post_media_upload_example_runs
      stub_path(:post, "media/upload", {data: {id: "7", media_key: "3_7"}})
      stub_path(:post, "media/metadata", {data: {id: "7", associated_metadata: {alt_text: {text: "Describe the image for people who cannot see it"}}}})
      stub_path(:post, "tweets", {data: {id: "9", text: "Posting media from @gem!"}})

      assert_equal "9\n", run_example("post_media_upload")
      assert_requested :post, "#{BASE}media/metadata", body: {id: "7", metadata: {alt_text: {text: "Describe the image for people who cannot see it"}}}.to_json
      assert_requested :post, "#{BASE}tweets", body: {text: "Posting media from @gem!", media: {media_ids: ["7"]}}.to_json
    end

    def test_the_profile_upload_example_runs
      stub_request(:post, "#{V1_BASE}account/update_profile_image.json").to_return(body: JSON.generate({id_str: "1", screen_name: "sferik"}), headers: {"content-type" => "application/json"})
      stub_request(:post, "#{V1_BASE}account/update_profile_banner.json").to_return(status: 201)
      stub_path(:get, "users/me", {data: {id: "1", username: "sferik"}})

      assert_equal "Profile image updated for @sferik\nProfile banner updated successfully\nProfile banner updated with custom dimensions\n", run_example("profile_upload")
      assert_requested :post, "#{V1_BASE}account/update_profile_banner.json", times: 2
    end

    private

    def follower(id, username) = {id:, username:, public_metrics: {followers_count: 5}}

    def path_pattern(path) = %r{\A#{Regexp.escape("#{BASE}#{path}")}(\?|\z)}

    def stub_path(method, path, body)
      stub_request(method, path_pattern(path)).to_return(body: JSON.generate(body), headers: {"content-type" => "application/json"})
    end

    def stub_stream_rules
      stub_path(:get, "tweets/search/stream/rules", {data: [{id: "1", value: "cats", tag: "cats"}], meta: {result_count: 1}})
      stub_path(:post, "tweets/search/stream/rules", {meta: {summary: {deleted: 1}}}).with(body: hash_including("delete"))
      stub_path(:post, "tweets/search/stream/rules", {data: [{id: "2", value: "ruby lang", tag: "ruby"}, {id: "3", value: "#opensource", tag: "opensource"}],
                                                     meta: {summary: {created: 2}}}).with(body: hash_including("add"))
    end

    # Stub the stream to deliver the posts and end, and to raise StreamEnded when the example reconnects, as it does
    # after a stream ends for as long as it runs
    def stub_stream(*posts)
      stub_request(:get, path_pattern("tweets/search/stream")).to_return(body: posts.map { |post| "#{JSON.generate(post)}\r\n" }.join).then.to_raise(StreamEnded)
    end

    # Run an example in an empty directory that holds the files it reads, wrapped in a module of its own, and return
    # what it printed, which @output holds too, should it raise
    def run_example(name)
      @output = StringIO.new
      Dir.mktmpdir do |dir|
        write_media(dir)
        printing_to(@output) { Dir.chdir(dir) { load File.join(EXAMPLES_DIR, "#{name}.rb"), true } }
      end
      @output.string
    end

    def write_media(dir)
      MEDIA.each do |path, content|
        FileUtils.mkdir_p(File.join(dir, File.dirname(path)))
        File.binwrite(File.join(dir, path), content)
      end
    end

    def printing_to(io)
      stdout, $stdout = $stdout, io
      yield
    ensure
      $stdout = stdout
    end
  end
end
