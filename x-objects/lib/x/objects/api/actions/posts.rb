require_relative "../../post"

module X
  module Objects
    module API
      module Actions
        # Create and delete posts as the authenticated user
        # @api public
        module Posts
          # Create a post as the authenticated user
          #
          # The API bills each post created, and bills a post whose text holds a URL more than ten times as much.
          #
          # @api public
          # @param text [String] the text of the post
          # @param params [Hash] additional request body fields, such as reply_to, quote, media_ids, or poll
          # @return [Post, nil] the created post, holding only its identifier and text
          # @example Create a post
          #   client.create_post("Hello, World!")
          # @example Reply to a post with an image
          #   client.create_post("Hello!", reply_to: post, media_ids: [media["id"]])
          # @example Quote a post
          #   client.create_post("Worth reading", quote: post)
          def create_post(text, **params)
            Post.create(text, client: self, **params)
          end

          # Delete a post as the authenticated user
          #
          # @api public
          # @param post [Post, String, Integer] the post or its identifier
          # @return [Boolean] true if the post was deleted
          # @example Delete a post
          #   client.delete_post("1234567890")
          def delete_post(post)
            Post.delete(post, client: self)
          end

          # Hide a reply to a post of the authenticated user
          #
          # @api public
          # @param post [Post, String, Integer] the reply or its identifier
          # @return [Boolean] true if the reply is now hidden
          # @example Hide a reply
          #   client.hide_reply("1234567890")
          def hide_reply(post)
            Post.hide(post, client: self)
          end

          # Show a reply to a post of the authenticated user after hiding it
          #
          # @api public
          # @param post [Post, String, Integer] the reply or its identifier
          # @return [Boolean] true if the reply is no longer hidden
          # @example Show a hidden reply
          #   client.unhide_reply("1234567890")
          def unhide_reply(post)
            Post.unhide(post, client: self)
          end

          alias_method :create_tweet, :create_post
          alias_method :delete_tweet, :delete_post
        end
      end
    end
  end
end
