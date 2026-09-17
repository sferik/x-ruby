require_relative "../test_helper"

module X
  class ClientUploaderAPITest < Minitest::Test
    BASE = "https://api.x.com/2/".freeze

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_client_includes_uploader_api
      assert_includes Client.ancestors, Uploader::API
    end

    def test_the_upload_methods_take_the_name_of_no_other_method_of_the_client
      others = (Client.ancestors - [Uploader::API]).flat_map { |ancestor| ancestor.instance_methods(false) + ancestor.private_instance_methods(false) }

      assert_empty Uploader::API.instance_methods & others
    end

    def test_a_client_uploads_media_and_posts_it
      stub_json(:post, "media/upload", {data: {id: "7", media_key: "3_7"}})
      stub_json(:post, "tweets", {data: {id: "9", text: "Look at this cat"}})
      media = @client.upload_media_binary("GIF89a", media_category: "tweet_image")

      assert_equal 9, @client.create_post("Look at this cat", media_ids: [media]).id
      assert_requested :post, "#{BASE}tweets", body: {text: "Look at this cat", media: {media_ids: ["7"]}}.to_json
    end

    def test_a_client_looks_up_the_media_that_an_upload_became
      stub_json(:post, "media/upload", {data: {id: "7", media_key: "3_7"}})
      stub_request(:get, %r{\A#{Regexp.escape(BASE)}media/3_7\?}o).to_return(body: JSON.generate({data: {media_key: "3_7", type: "photo"}}), headers: {"content-type" => "application/json"})
      uploaded = @client.upload_media_binary("GIF89a", media_category: "tweet_image")

      assert_equal "photo", @client.find_media(uploaded.media_key).type
    end

    private

    def stub_json(method, path, body)
      stub_request(method, "#{BASE}#{path}").to_return(body: JSON.generate(body), headers: {"content-type" => "application/json"})
    end
  end
end
