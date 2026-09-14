require "json"
require_relative "cursor"
require_relative "referenced_posts"
require_relative "resource"

module X
  # A post, also known as a tweet
  # @api public
  class Post < Objects::Resource
    # Every public post field
    FIELDS = %w[attachments author_id context_annotations conversation_id created_at edit_controls
      edit_history_tweet_ids entities geo id in_reply_to_user_id lang note_tweet possibly_sensitive
      public_metrics referenced_tweets reply_settings source text withheld].freeze
    # Every expansion available on post endpoints
    EXPANSIONS = %w[attachments.media_keys attachments.poll_ids author_id edit_history_tweet_ids
      entities.mentions.username geo.place_id in_reply_to_user_id referenced_tweets.id
      referenced_tweets.id.author_id].freeze
    # Maximum number of posts or users per page
    MAX_RESULTS = 100

    include Objects::ReferencedPosts

    class << self
      # The API endpoint used to look up posts by identifier
      #
      # @api public
      # @return [String] the endpoint
      # @example Get the endpoint
      #   X::Post.endpoint # => "tweets"
      def endpoint
        "tweets"
      end

      # The key under which posts appear in the includes of a response
      #
      # @api public
      # @return [String] the includes key
      # @example Get the includes key
      #   X::Post.includes_key # => "tweets"
      def includes_key
        "tweets"
      end

      # The default query parameters requesting every post field and expansion
      #
      # @api public
      # @return [Hash{String => Array<String>}] the default query parameters
      # @example Get the default parameters
      #   X::Post.default_params["tweet.fields"]
      def default_params
        {"tweet.fields" => FIELDS, "user.fields" => User::FIELDS, "media.fields" => Media::FIELDS,
         "poll.fields" => Poll::FIELDS, "place.fields" => Place::FIELDS, "expansions" => EXPANSIONS}
      end

      # Search recent posts
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the matching posts
      # @example Print posts about Ruby
      #   X::Post.search("ruby -is:retweet", client: client).each { |post| puts post.text }
      def search(query, client:, **params)
        Cursor.new(self, client:, path: "tweets/search/recent", params: {query:, max_results: MAX_RESULTS}.merge(params))
      end

      # Search the full archive of posts
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the matching posts
      # @example Print every post about Ruby
      #   X::Post.search_all("ruby -is:retweet", client: client).each { |post| puts post.text }
      def search_all(query, client:, **params)
        Cursor.new(self, client:, path: "tweets/search/all", params: {query:, max_results: MAX_RESULTS}.merge(params))
      end

      # Create a post as the authenticated user
      #
      # @api public
      # @param text [String] the text of the post
      # @param client [Object] the client used to make the request
      # @param params [Hash] additional request body fields, such as reply or media
      # @return [Post, nil] the created post, holding only its identifier and text
      # @example Create a post
      #   X::Post.create("Hello, World!", client: client)
      def create(text, client:, **params)
        body = client.post("tweets", JSON.generate({text:, **params}), **Objects::Utils::JSON_CLASSES)
        resource_from_response(body, client:)
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
        body = client.delete("tweets/#{Objects::Utils.id_of(post)}", **Objects::Utils::JSON_CLASSES)
        body.to_h.dig("data", "deleted").eql?(true)
      end
    end

    # @!attribute [r] text
    #   The text
    #   @api public
    #   @return [String, nil] the text
    #   @example Get the text
    #     post.text
    attribute :text

    # @!attribute [r] lang
    #   The BCP 47 language tag
    #   @api public
    #   @return [String, nil] the language tag
    #   @example Get the language
    #     post.lang
    attribute :lang

    # @!attribute [r] source
    #   The name of the app used to create the post
    #   @api public
    #   @return [String, nil] the source
    #   @example Get the source
    #     post.source
    attribute :source

    # @!attribute [r] created_at
    #   The time when the post was created
    #   @api public
    #   @return [Time, nil] the creation time
    #   @example Get the creation time
    #     post.created_at
    attribute :created_at, :time

    # @!attribute [r] author_id
    #   The identifier of the author
    #   @api public
    #   @return [String, nil] the author identifier
    #   @example Get the author identifier
    #     post.author_id
    attribute :author_id

    # @!attribute [r] conversation_id
    #   The identifier of the first post in the conversation
    #   @api public
    #   @return [String, nil] the conversation identifier
    #   @example Get the conversation identifier
    #     post.conversation_id
    attribute :conversation_id

    # @!attribute [r] in_reply_to_user_id
    #   The identifier of the user being replied to
    #   @api public
    #   @return [String, nil] the replied-to user identifier
    #   @example Get the replied-to user identifier
    #     post.in_reply_to_user_id
    attribute :in_reply_to_user_id

    # @!attribute [r] possibly_sensitive
    #   Whether the post may contain sensitive content
    #   @api public
    #   @return [Boolean, nil] true if the post may be sensitive
    #   @example Check whether a post may be sensitive
    #     post.possibly_sensitive?
    attribute :possibly_sensitive, :boolean

    # @!method possibly_sensitive?
    #   Check whether the post may contain sensitive content
    #   @api public
    #   @return [Boolean] true if the post may be sensitive
    #   @example Check whether the post may contain sensitive content
    #     post.possibly_sensitive?

    # @!attribute [r] reply_settings
    #   Who can reply: everyone, mentionedUsers, or following
    #   @api public
    #   @return [String, nil] the reply settings
    #   @example Get the reply settings
    #     post.reply_settings
    attribute :reply_settings

    # @!attribute [r] edit_history_post_ids
    #   The identifiers of every version of the post
    #   @api public
    #   @return [Array<String>, nil] the edit history identifiers
    #   @example Get the edit history identifiers
    #     post.edit_history_post_ids
    attribute :edit_history_post_ids, key: %w[edit_history_tweet_ids]

    # @!attribute [r] edit_controls
    #   The edit controls
    #   @api public
    #   @return [Hash, nil] the edit controls
    #   @example Get the edit controls
    #     post.edit_controls
    attribute :edit_controls

    # @!attribute [r] entities
    #   The entities found in the text
    #   @api public
    #   @return [Hash, nil] the entities
    #   @example Get the entities
    #     post.entities
    attribute :entities

    # @!attribute [r] context_annotations
    #   The context annotations
    #   @api public
    #   @return [Array<Hash>, nil] the context annotations
    #   @example Get the context annotations
    #     post.context_annotations
    attribute :context_annotations

    # @!attribute [r] referenced_tweets
    #   The referenced posts with their types and identifiers
    #   @api public
    #   @return [Array<Hash>, nil] the referenced posts
    #   @example Get the referenced posts
    #     post.referenced_tweets
    attribute :referenced_tweets

    # @!attribute [r] attachments
    #   The attachment keys and identifiers
    #   @api public
    #   @return [Hash, nil] the attachments
    #   @example Get the attachments
    #     post.attachments
    attribute :attachments

    # @!attribute [r] geo
    #   The tagged place and coordinates
    #   @api public
    #   @return [Hash, nil] the geo details
    #   @example Get the geo details
    #     post.geo
    attribute :geo

    # @!attribute [r] withheld
    #   The withholding details
    #   @api public
    #   @return [Hash, nil] the withholding details
    #   @example Get the withholding details
    #     post.withheld
    attribute :withheld

    # @!attribute [r] note_post
    #   The full text and entities of a long post
    #   @api public
    #   @return [Hash, nil] the note details
    #   @example Get the note details
    #     post.note_post
    attribute :note_post, key: %w[note_tweet]

    # @!attribute [r] public_metrics
    #   The public metrics
    #   @api public
    #   @return [Hash, nil] the public metrics
    #   @example Get the public metrics
    #     post.public_metrics
    attribute :public_metrics

    # @!attribute [r] repost_count
    #   The number of reposts
    #   @api public
    #   @return [Integer, nil] the repost count
    #   @example Get the repost count
    #     post.repost_count
    attribute :repost_count, key: %w[public_metrics retweet_count]

    # @!attribute [r] reply_count
    #   The number of replies
    #   @api public
    #   @return [Integer, nil] the reply count
    #   @example Get the reply count
    #     post.reply_count
    attribute :reply_count, key: %w[public_metrics reply_count]

    # @!attribute [r] like_count
    #   The number of likes
    #   @api public
    #   @return [Integer, nil] the like count
    #   @example Get the like count
    #     post.like_count
    attribute :like_count, key: %w[public_metrics like_count]

    # @!attribute [r] quote_count
    #   The number of quotes
    #   @api public
    #   @return [Integer, nil] the quote count
    #   @example Get the quote count
    #     post.quote_count
    attribute :quote_count, key: %w[public_metrics quote_count]

    # @!attribute [r] bookmark_count
    #   The number of bookmarks
    #   @api public
    #   @return [Integer, nil] the bookmark count
    #   @example Get the bookmark count
    #     post.bookmark_count
    attribute :bookmark_count, key: %w[public_metrics bookmark_count]

    # @!attribute [r] impression_count
    #   The number of impressions
    #   @api public
    #   @return [Integer, nil] the impression count
    #   @example Get the impression count
    #     post.impression_count
    attribute :impression_count, key: %w[public_metrics impression_count]

    # @!method author
    #   The author, resolved from the includes or as a stub holding only its identifier
    #   @api public
    #   @return [User, nil] the author
    #   @example Get the author's username
    #     post.author.username
    reference :author, :User, key: %w[author_id]

    # @!method in_reply_to_user
    #   The user being replied to, resolved from the includes or built as a stub
    #   @api public
    #   @return [User, nil] the replied-to user
    #   @example Get the replied-to user
    #     post.in_reply_to_user
    reference :in_reply_to_user, :User, key: %w[in_reply_to_user_id]

    # @!method place
    #   The tagged place, from the includes or as a stub holding only its identifier
    #   @api public
    #   @return [Place, nil] the place
    #   @example Get the place
    #     post.place
    reference :place, :Place, key: %w[geo place_id]

    # @!method media
    #   The attached media, from the includes or as stubs holding only their keys
    #   @api public
    #   @return [Array<Media>] the media
    #   @example Get the media URLs
    #     post.media.map(&:url)
    references :media, :Media, key: %w[attachments media_keys]

    # @!method polls
    #   The attached polls, from the includes or as stubs holding only their identifiers
    #   @api public
    #   @return [Array<Poll>] the polls
    #   @example Get the poll options
    #     post.polls.first.options
    references :polls, :Poll, key: %w[attachments poll_ids]

    alias_method :retweet_count, :repost_count
    alias_method :edit_history_tweet_ids, :edit_history_post_ids
    alias_method :note_tweet, :note_post

    # The users who liked this post
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the liking users
    # @example Print the liking users
    #   post.liking_users.each { |user| puts user.username }
    def liking_users(**params)
      cursor(User, "tweets/#{id}/liking_users", max_results: MAX_RESULTS, **params)
    end

    # The users who reposted this post
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the reposting users
    # @example Print the reposting users
    #   post.reposted_by.each { |user| puts user.username }
    def reposted_by(**params)
      cursor(User, "tweets/#{id}/retweeted_by", max_results: MAX_RESULTS, **params)
    end

    # The posts quoting this post
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the quotes
    # @example Print the quotes
    #   post.quotes.each { |quote| puts quote.text }
    def quotes(**params)
      cursor(Post, "tweets/#{id}/quote_tweets", max_results: MAX_RESULTS, **params)
    end

    # Delete this post as the authenticated user
    #
    # @api public
    # @return [Boolean] true if the post was deleted
    # @example Delete a post
    #   post.delete
    def delete
      self.class.delete(self, client: client!)
    end

    alias_method :retweeted_by, :reposted_by
  end

  # Alias for Post
  Tweet = Post
end
