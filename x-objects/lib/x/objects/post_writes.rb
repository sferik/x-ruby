# frozen_string_literal: true

require_relative "utils"

module X
  module Objects
    # Creating and deleting posts, and hiding replies, as the authenticated user
    # @api public
    module PostWrites
      # Create a post as the authenticated user
      #
      # The API bills each post created, and bills a post whose text holds a URL more than ten times as much.
      # A post needs no text when it has something else to show, such as media.
      #
      # @api public
      # @param text [String, nil] the text of the post, or nil for a post without text, such as one of media alone
      # @param client [Object] the client used to make the request
      # @param reply_to [Post, String, Integer, nil] the post to reply to or its identifier
      # @param quote [Post, String, Integer, nil] the post to quote or its identifier
      # @param media_ids [Array<String, Integer, #fetch, Media>, String, Integer, #fetch, Media, nil] the identifiers of
      #   uploaded media to attach, what the uploads returned, or media, such as that of a post, one or many; an
      #   empty list attaches nothing, as nil does
      # @param community [Community, String, Integer, nil] the community to post in or its identifier
      # @param params [Hash] additional request body fields, such as poll or reply_settings, among them reply and
      #   media, whose other fields reply_to and media_ids are merged into
      # @return [Post, nil] the created post, holding only its identifier and text
      # @raise [ArgumentError] if the post has neither text nor any other field, which an empty media_ids is not
      # @example Create a post
      #   X::Post.create("Hello, World!", client: client)
      # @example Post an image without text
      #   X::Post.create(client: client, media_ids: media)
      # @example Reply to a post with an image
      #   X::Post.create("Hello!", client: client, reply_to: post, media_ids: [media["id"]])
      # @example Reply without the users a thread would otherwise mention
      #   X::Post.create("Hello!", client: client, reply_to: post, reply: {exclude_reply_user_ids: ["7505382"]})
      # @example Post in a community
      #   X::Post.create("Hello, Rubyists!", client: client, community: community)
      # @example Quote a post
      #   X::Post.create("Worth reading", client: client, quote: post)
      def create(text = nil, client:, reply_to: nil, quote: nil, media_ids: nil, community: nil, **params)
        fields = {text:, **params, **referenced(params, reply_to:, quote:, media_ids:, community:)}.compact
        raise ArgumentError, "a post needs text, or something else to show, such as media_ids" if fields.empty?

        resource_from_response(client.post("tweets", fields, **Utils::JSON_CLASSES), client:)
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

      # Hide a reply to a post of the authenticated user
      #
      # X still shows a hidden reply, behind a notice that its author was hidden.
      #
      # @api public
      # @param post [Post, String, Integer] the reply or its identifier
      # @param client [Object] the client used to make the request
      # @return [Boolean] true if the reply is now hidden
      # @example Hide a reply
      #   X::Post.hide_reply("1234567890", client: client)
      def hide_reply(post, client:)
        change_visibility(post, true, client:).eql?(true)
      end

      # Show a reply that was hidden, as the author of the post it replies to
      #
      # @api public
      # @param post [Post, String, Integer] the reply or its identifier
      # @param client [Object] the client used to make the request
      # @return [Boolean] true if the reply is no longer hidden
      # @example Show a hidden reply
      #   X::Post.unhide_reply("1234567890", client: client)
      def unhide_reply(post, client:)
        change_visibility(post, false, client:).eql?(false)
      end

      private

      # Hide or show a reply, and read whether it is hidden
      # @api private
      # @param post [Post, String, Integer] the reply or its identifier
      # @param hidden [Boolean] whether to hide the reply
      # @param client [Object] the client used to make the request
      # @return [Boolean, nil] whether the reply is hidden, as the response reports, or nil if it does not
      def change_visibility(post, hidden, client:)
        client.put("tweets/#{Utils.id_of(post)}/hidden", {hidden:}, **Utils::JSON_CLASSES).to_h.dig("data", "hidden")
      end

      # The fields of a new post that refer to other posts, media, or a community
      #
      # The API nests the post replied to within reply, and the media within media, beside other fields a caller may
      # set, so reply_to and media_ids are merged into what the caller gave rather than replace it, and they win the
      # one field each of them sets. An empty media_ids sets no media field, which the API would refuse.
      #
      # @api private
      # @param params [Hash] the request body fields the caller gave, such as reply, media, or poll
      # @param reply_to [Post, String, Integer, nil] the post to reply to or its identifier
      # @param quote [Post, String, Integer, nil] the post to quote or its identifier
      # @param media_ids [Array, #fetch, Media, String, Integer, nil] the identifiers of uploaded media, what the uploads
      #   returned, or media, one or many
      # @param community [Community, String, Integer, nil] the community to post in or its identifier
      # @return [Hash{Symbol => Object}] the fields, without those given nil
      def referenced(params, reply_to:, quote:, media_ids:, community:)
        fields = {} #: Hash[Symbol, untyped]
        fields[:reply] = merged(params, :reply, in_reply_to_tweet_id: Utils.id_of(reply_to)) unless reply_to.nil?
        fields[:quote_tweet_id] = Utils.id_of(quote) unless quote.nil?
        ids = Utils.media_ids_of(media_ids)
        fields[:media] = merged(params, :media, media_ids: ids) unless ids.empty?
        fields[:community_id] = Utils.id_of(community) unless community.nil?
        fields
      end

      # One nested field, with the convenience key merged over what the caller gave
      #
      # @api private
      # @param params [Hash] the request body fields the caller gave
      # @param key [Symbol] the nested field, reply or media
      # @param field [Hash] the one field the convenience key sets, which wins
      # @return [Hash{Symbol => Object}] the nested field
      def merged(params, key, **field) = params[key].to_h.merge(field)
    end
  end
end
