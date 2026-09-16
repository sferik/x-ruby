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
          # @param params [Hash] additional request body fields, such as reply_to, media_ids, or poll
          # @return [Post, nil] the created post, holding only its identifier and text
          # @example Create a post
          #   client.create_post("Hello, World!")
          # @example Reply to a post with an image
          #   client.create_post("Hello!", reply_to: post, media_ids: [media["id"]])
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

          alias_method :create_tweet, :create_post
          alias_method :delete_tweet, :delete_post
        end
      end
    end
  end
end
