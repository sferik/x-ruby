require "json"
require_relative "utils"

module X
  module Objects
    # Creating and deleting posts, as the authenticated user
    # @api public
    module PostWrites
      # Create a post as the authenticated user
      #
      # The API bills each post created, and bills a post whose text holds a URL more than ten times as much.
      #
      # @api public
      # @param text [String] the text of the post
      # @param client [Object] the client used to make the request
      # @param reply_to [Post, String, Integer, nil] the post to reply to or its identifier
      # @param quote [Post, String, Integer, nil] the post to quote or its identifier
      # @param media_ids [Array<String, Integer, Hash>, nil] the identifiers of uploaded media to attach, or the upload responses
      # @param community [Community, String, Integer, nil] the community to post in or its identifier
      # @param params [Hash] additional request body fields, such as poll or reply_settings
      # @return [Post, nil] the created post, holding only its identifier and text
      # @example Create a post
      #   X::Post.create("Hello, World!", client: client)
      # @example Reply to a post with an image
      #   X::Post.create("Hello!", client: client, reply_to: post, media_ids: [media["id"]])
      # @example Post in a community
      #   X::Post.create("Hello, Rubyists!", client: client, community: community)
      # @example Quote a post
      #   X::Post.create("Worth reading", client: client, quote: post)
      def create(text, client:, reply_to: nil, quote: nil, media_ids: nil, community: nil, **params)
        fields = {text:, **params, **referenced(reply_to:, quote:, media_ids:, community:)}
        resource_from_response(client.post("tweets", JSON.generate(fields), **Utils::JSON_CLASSES), client:)
      end

      # Delete a post as the authenticated user
      #
      # @api public
      # @param post [Post, String, Integer] the post or its identifier
      # @param client [Object] the client used to make the request
      # @return [Boolean] true if the post was deleted
      # @example Delete a post
      #   X::Post.delete("1234567890", client: client)
      def delete(post, client:)
        body = client.delete("tweets/#{Utils.id_of(post)}", **Utils::JSON_CLASSES)
        body.to_h.dig("data", "deleted").eql?(true)
      end

      private

      # The fields of a new post that refer to other posts, media, or a community
      # @api private
      # @param reply_to [Post, String, Integer, nil] the post to reply to or its identifier
      # @param quote [Post, String, Integer, nil] the post to quote or its identifier
      # @param media_ids [Array<String, Integer, Hash>, nil] the identifiers of uploaded media, or the upload responses
      # @param community [Community, String, Integer, nil] the community to post in or its identifier
      # @return [Hash{Symbol => Object}] the fields, without those given nil
      def referenced(reply_to:, quote:, media_ids:, community:)
        fields = {} #: Hash[Symbol, untyped]
        fields[:reply] = {in_reply_to_tweet_id: Utils.id_of(reply_to)} unless reply_to.nil?
        fields[:quote_tweet_id] = Utils.id_of(quote) unless quote.nil?
        fields[:media] = {media_ids: media_ids.map { |media| Utils.media_id_of(media) }} unless media_ids.nil?
        fields[:community_id] = Utils.id_of(community) unless community.nil?
        fields
      end
    end
  end
end
