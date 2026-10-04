# frozen_string_literal: true

require "cgi/escape"
require "json"
require "uri"
require_relative "batch_finders"
require_relative "community"
require_relative "matching_rule"
require_relative "cursor"
require_relative "post_collections"
require_relative "post_counts"
require_relative "post_search"
require_relative "post_writes"
require_relative "references"
require_relative "resource"

module X
  module Resources
    # A post, also known as a tweet
    # @api public
    class ::X::Post < Resource
      # The mixins of the class by their full names, which YARD needs to resolve them in a class opened under X; they
      # stand apart from the mixins, since YARD reads a comment that code follows as the documentation of that code
      #
      # @!parse
      #   include X::Resources::References
      #   include X::Resources::PostCollections
      #   extend X::Resources::BatchFinders
      #   extend X::Resources::PostCounts
      #   extend X::Resources::PostSearch
      #   extend X::Resources::PostWrites

      # Every public post field; the identifiers of referenced resources come with their expansions
      #
      # The metrics that only the author, or an advertiser, may read, non_public_metrics, organic_metrics, and
      # promoted_metrics, are left out, since a field that depends on who is authenticated would make every request
      # fail for a client that cannot read it, as are the fields of Community Notes and of suggested sources, which the
      # API gives to the programs they belong to. So is source, which the API has deprecated: a field it stops taking
      # would make every request that asks for it fail. Nor does a post read it; a request that names it in its
      # post.fields finds it in {Resource#attrs}.
      #
      # A minor release may add to it the fields the API adds, so that a lookup asks for them too; see
      # {Resource#hydrated?} for what that means for a resource looked up with a list of fields of its own.
      FIELDS = %w[article article_title attachments card_uri community_id context_annotations conversation_id
        created_at display_text_range edit_controls entities geo id lang media_metadata note_post paid_partnership
        possibly_sensitive public_metrics reply_settings scopes text withheld].freeze
      # The expansions of the resources a post refers to that the object layer resolves
      #
      # The identifiers of a post's edit history come with every post, so the edit_history_post_ids expansion, which
      # would include each version of the post again, including the post itself, is left out, as is
      # entities.mentions.username, which would include each user the post mentions, since nothing reads them.
      #
      # A minor release may add to it the expansions the API adds, so that a lookup asks for them too; see
      # {Resource#hydrated?} for what that means for a resource looked up with a list of expansions of its own.
      EXPANSIONS = %w[attachments.media_keys attachments.media_source_tweet attachments.poll_ids author_id geo.place_id
        in_reply_to_user_id referenced_posts].freeze

      include References
      include PostCollections
      extend BatchFinders
      extend PostCounts
      extend PostSearch
      extend PostWrites

      class << self
        # The API endpoint used to look up posts by identifier
        #
        # @api private
        # @return [String] the endpoint
        # @example Get the endpoint
        #   X::Post.__send__(:endpoint) # => "tweets"
        def endpoint = "tweets"

        # The key under which posts appear in the includes of a response
        #
        # @api private
        # @return [String] the includes key
        # @example Get the includes key
        #   X::Post.__send__(:includes_key) # => "posts"
        def includes_key = "posts"

        # The query parameter that selects post fields
        #
        # @api private
        # @return [String] the fields parameter
        # @example Get the fields parameter
        #   X::Post.__send__(:fields_key) # => "post.fields"
        def fields_key = "post.fields"

        private :endpoint, :includes_key, :fields_key

        # The default query parameters requesting every post field and expansion
        #
        # @api public
        # @return [Hash{String => Array<String>}] the default query parameters
        # @example Get the default parameters
        #   X::Post.default_params["post.fields"]
        def default_params
          {"post.fields" => FIELDS, "user.fields" => User::FIELDS, "media.fields" => Media::FIELDS,
           "poll.fields" => Poll::FIELDS, "place.fields" => Place::FIELDS, "expansions" => EXPANSIONS}
        end
      end

      # The full text
      #
      # A long post, of more than 280 characters, holds its full text in note_post, and a text cut short with an
      # ellipsis and a link to the post; this reads the full text.
      #
      # It is the text as the API sends it, which escapes &, <, and > as &amp;, &lt;, and &gt;, and it stays so
      # throughout 1.x, so unescape it to display it.
      #
      # @api public
      # @return [String, nil] the text, HTML-escaped as the API sends it
      # @raise [InvalidAttribute] if the response holds a note_post that is not an object
      # @example Get the text
      #   post.text # => "Ruby &amp; Rails"
      # @example Display the text
      #   CGI.unescapeHTML(post.text) # => "Ruby & Rails"
      def text = full["text"]

      # @!attribute [r] lang
      #   The BCP 47 language tag
      #   @api public
      #   @return [String, nil] the language tag
      #   @example Get the language
      #     post.lang
      attribute :lang

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
      #   @return [Integer, nil] the author identifier
      #   @example Get the author identifier
      #     post.author_id
      attribute :author_id, :integer

      # @!attribute [r] conversation_id
      #   The identifier of the first post in the conversation
      #   @api public
      #   @return [Integer, nil] the conversation identifier
      #   @example Get the conversation identifier
      #     post.conversation_id
      attribute :conversation_id, :integer

      # @!attribute [r] community_id
      #   The identifier of the community the post was made in
      #   @api public
      #   @return [Integer, nil] the community identifier
      #   @example Get the community identifier
      #     post.community_id
      attribute :community_id, :integer

      # @!attribute [r] in_reply_to_user_id
      #   The identifier of the user being replied to
      #   @api public
      #   @return [Integer, nil] the replied-to user identifier
      #   @example Get the replied-to user identifier
      #     post.in_reply_to_user_id
      attribute :in_reply_to_user_id, :integer

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
      #   @return [Array<Integer>] the edit history identifiers, empty if there are none
      #   @example Get the edit history identifiers
      #     post.edit_history_post_ids
      attribute :edit_history_post_ids, :integers, tweet_key: %w[edit_history_tweet_ids]

      # @!attribute [r] edit_controls
      #   The edit controls
      #   @api public
      #   @return [Hash, nil] the edit controls
      #   @example Get the edit controls
      #     post.edit_controls
      attribute :edit_controls, :object

      # @!attribute [r] display_text_range
      #   The range of characters of the text the API gives the post that is shown
      #
      #   It leaves out the mentions a reply begins with and the link to media it ends with. It is a range of the text
      #   the post holds itself, which for a long post is the text cut short, not the full text {#text} reads.
      #
      #   @api public
      #   @return [Range<Integer>, nil] the range, which leaves out its end, or nil if the response holds none
      #   @raise [InvalidAttribute] if the response holds something other than the start and end of a range
      #   @example Read the text that is shown
      #     post.display_text_range&.then { |range| post.attrs["text"][range] }
      attribute :display_text_range, :range

      # @!attribute [r] scopes
      #   Who may see the post
      #
      #   A post its author shared with followers alone holds `{"followers" => true}`.
      #
      #   @api public
      #   @return [Hash, nil] the scopes
      #   @example Check whether the post is shared with followers alone
      #     post.scopes&.fetch("followers", false)
      attribute :scopes, :object

      # @!attribute [r] card_uri
      #   The URI of the card the post shows
      #   @api public
      #   @return [String, nil] the card URI
      #   @example Get the card URI
      #     post.card_uri
      attribute :card_uri

      # @!attribute [r] article
      #   The article the post publishes, with its title
      #   @api public
      #   @return [Hash, nil] the article
      #   @example Get the title of an article
      #     post.article&.fetch("title")
      attribute :article, :object

      # @!attribute [r] article_title
      #   What the API describes of the title of the article the post publishes
      #   @api public
      #   @return [Hash, nil] the metadata of the article, or nil for a post that publishes none
      #   @example Get the metadata of the title of an article
      #     post.article_title
      attribute :article_title, :object

      # @!attribute [r] media_metadata
      #   What the post describes of the media it attaches
      #   @api public
      #   @return [Array<Hash>] the metadata of each medium, empty if there is none
      #   @example Get the metadata of the media
      #     post.media_metadata
      attribute :media_metadata, :objects

      # @!attribute [r] paid_partnership
      #   Whether the post is a paid partnership
      #   @api public
      #   @return [Boolean, nil] true if the post is a paid partnership
      #   @example Check whether a post is a paid partnership
      #     post.paid_partnership?
      attribute :paid_partnership, :boolean

      # @!method paid_partnership?
      #   Check whether the post is a paid partnership
      #   @api public
      #   @return [Boolean] true if the post is a paid partnership
      #   @example Check whether the post is a paid partnership
      #     post.paid_partnership?

      # The entities found in the full text
      #
      # The entities, such as links, mentions, and hashtags, come from note_post for a long post, whose note the API
      # gives entities when the full text has any, and from the post itself for a short one, so that each lies where
      # {#text} holds it. A long post whose note holds none has none: the entities the post holds itself, such as its
      # annotations, lie in the text cut short, which attrs holds.
      #
      # @api public
      # @return [Hash, nil] the entities
      # @raise [InvalidAttribute] if the response holds a note_post, or entities, that is not an object
      # @example Get the entities
      #   post.entities
      def entities = Shape.read_object("#{self.class}#entities", full["entities"])

      # The links in the full text, each with its shortened url and its expanded_url
      #
      # @api public
      # @return [Array<Hash>] the links, empty if there are none
      # @raise [InvalidAttribute] if the response holds entities, or links, that are not what the API documents
      # @example Get the links
      #   post.urls # => [{"url" => "https://t.co/...", "expanded_url" => "https://github.com/sferik/x-ruby", ...}]
      def urls = Shape.objects("#{self.class}#urls", entities&.[]("urls"))

      # The rules of the filtered stream this post matched
      #
      # A post the filtered stream delivers names the rules it matched, and any other post names none. The streaming
      # client of x-streams builds the posts of a stream given X::Post as its object_class.
      #
      # @api public
      # @return [Array<MatchingRule>] the rules, empty for a post that did not come from the filtered stream
      # @raise [InvalidAttribute] if the response holds the rules as something other than a list of objects, or a rule
      #   without an identifier that is a number, or with a tag that is not a String
      # @example Print the tags of the rules each post of the filtered stream matched
      #   streaming_client.stream("tweets/search/stream", object_class: X::Post) { |post| p post.matching_rules.map(&:tag) }
      def matching_rules
        reader = "#{self.class}#matching_rules"
        Shape.objects(reader, attrs["matching_rules"]).map { |rule| Utils.read(reader, rule) { MatchingRule.new(rule) } }.freeze
      end

      attribute_names.push(:text, :entities, :urls, :matching_rules)

      # @!attribute [r] context_annotations
      #   The context annotations
      #   @api public
      #   @return [Array<Hash>] the context annotations, empty if there are none
      #   @example Get the context annotations
      #     post.context_annotations
      attribute :context_annotations, :objects

      # @!attribute [r] referenced_posts
      #   The referenced posts with their types and identifiers
      #   @api public
      #   @return [Array<Hash>] the referenced posts, empty if there are none
      #   @example Get the referenced posts
      #     post.referenced_posts
      attribute :referenced_posts, :objects, tweet_key: %w[referenced_tweets]
      reference_keys.push(%w[referenced_posts], %w[referenced_tweets])

      # @!attribute [r] attachments
      #   The attachment keys and identifiers
      #   @api public
      #   @return [Hash, nil] the attachments
      #   @example Get the attachments
      #     post.attachments
      attribute :attachments, :object

      # @!attribute [r] coordinates
      #   The longitude and latitude the post was tagged with
      #   @api public
      #   @return [Array<Numeric>, nil] the longitude and latitude, each an Integer when the API gives a whole number
      #   @example Get the coordinates
      #     post.coordinates # => [-122.4, 37.8]
      attribute :coordinates, key: %w[geo coordinates coordinates]

      # @!attribute [r] geo
      #   The tagged place and coordinates
      #   @api public
      #   @return [Hash, nil] the geo details
      #   @example Get the geo details
      #     post.geo
      attribute :geo, :object

      # @!attribute [r] withheld
      #   The withholding details
      #   @api public
      #   @return [Hash, nil] the withholding details
      #   @example Get the withholding details
      #     post.withheld
      attribute :withheld, :object

      # @!attribute [r] note_post
      #   The full text and entities of a long post
      #   @api public
      #   @return [Hash, nil] the note details
      #   @example Get the note details
      #     post.note_post
      attribute :note_post, :object, tweet_key: %w[note_tweet]

      # @!attribute [r] public_metrics
      #   The public metrics
      #   @api public
      #   @return [Hash, nil] the public metrics
      #   @example Get the public metrics
      #     post.public_metrics
      attribute :public_metrics, :object

      # @!attribute [r] repost_count
      #   The number of reposts
      #   @api public
      #   @return [Integer, nil] the repost count
      #   @example Get the repost count
      #     post.repost_count
      attribute :repost_count, :integer, key: %w[public_metrics repost_count], tweet_key: %w[public_metrics retweet_count]

      # @!attribute [r] reply_count
      #   The number of replies
      #   @api public
      #   @return [Integer, nil] the reply count
      #   @example Get the reply count
      #     post.reply_count
      attribute :reply_count, :integer, key: %w[public_metrics reply_count]

      # @!attribute [r] like_count
      #   The number of likes
      #   @api public
      #   @return [Integer, nil] the like count
      #   @example Get the like count
      #     post.like_count
      attribute :like_count, :integer, key: %w[public_metrics like_count]

      # @!attribute [r] quote_count
      #   The number of quotes
      #   @api public
      #   @return [Integer, nil] the quote count
      #   @example Get the quote count
      #     post.quote_count
      attribute :quote_count, :integer, key: %w[public_metrics quote_count]

      # @!attribute [r] bookmark_count
      #   The number of bookmarks
      #   @api public
      #   @return [Integer, nil] the bookmark count
      #   @example Get the bookmark count
      #     post.bookmark_count
      attribute :bookmark_count, :integer, key: %w[public_metrics bookmark_count]

      # @!attribute [r] impression_count
      #   The number of impressions
      #   @api public
      #   @return [Integer, nil] the impression count
      #   @example Get the impression count
      #     post.impression_count
      attribute :impression_count, :integer, key: %w[public_metrics impression_count]

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

      # @!method community
      #   The community the post was made in, as a stub holding only its identifier
      #   @api public
      #   @return [Community, nil] the community
      #   @example Get the community's name
      #     post.community.hydrate.name
      reference :community, :Community, key: %w[community_id]

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

      # @!method media_source_posts
      #   The posts the attached media was first posted with
      #
      #   A post that attaches media another post was made with, as one that shares a video does, names that post as
      #   the source of the media. Each is read from the includes, or built as a stub holding only its identifier.
      #
      #   @api public
      #   @return [Array<Post>] the posts, empty if the media was first posted with this post, or it has none
      #   @example Credit the author of shared media
      #     post.media_source_posts.map { |source| source.author&.username }
      references :media_source_posts, :Post, key: %w[attachments media_source_tweet_id]

      # The other names of attributes, as the aliases YARD reads them as
      #
      # @!parse
      #   alias_method :retweet_count, :repost_count
      #   alias_method :edit_history_tweet_ids, :edit_history_post_ids
      #   alias_method :note_tweet, :note_post
      #   alias_method :referenced_tweets, :referenced_posts
      attribute_alias :retweet_count, :repost_count
      attribute_alias :edit_history_tweet_ids, :edit_history_post_ids
      attribute_alias :note_tweet, :note_post
      attribute_alias :referenced_tweets, :referenced_posts
      alias_method :media_source_tweets, :media_source_posts

      # The permalink of the post, by the author's username when known
      #
      # @api public
      # @return [String] the x.com address of the post
      # @raise [InvalidAttribute] if the response holds the username of the author as something other than a String
      # @example Get the permalink
      #   post.permalink # => "https://x.com/sferik/status/1234567890"
      def permalink = "https://x.com/#{Shape.read_string("#{self.class}#permalink", author&.username) || "i"}/status/#{id}"

      # The permalink of the post as a URI
      #
      # @api public
      # @return [URI::Generic] the x.com address of the post
      # @raise [InvalidAttribute] if the response holds the username of the author as something other than a String
      # @example Get the address as a URI
      #   post.uri # => #<URI::HTTPS https://x.com/sferik/status/1234567890>
      def uri = URI(permalink)

      # The text with every shortened link replaced by the URL it stands for
      #
      # A link the API expanded to no URL is left as it is, and a link without a url, which the API documents as one
      # that may hold none, is passed over, as it holds nothing to replace.
      #
      # Every link is replaced in one pass over the text, so a URL a link stands for is never read for the links
      # after it, and holds what it holds, even the shortened url of another link of the post. A url that begins
      # another, longer one is not read in it.
      #
      # The rest of the text is as {#text} reads it, HTML-escaped as the API sends it, and each URL is HTML-escaped as
      # it is put in, since the API sends a URL as it is, so the whole text is escaped alike: unescape it to display it.
      #
      # @api public
      # @return [String, nil] the text with expanded links
      # @raise [InvalidAttribute] if the response holds a link whose url, or whose expanded_url beside a url, is neither
      #   a String nor null, or text that is not a String
      # @example Display a post with its links in full
      #   CGI.unescapeHTML(post.expanded_text)
      def expanded_text
        replacements = expansions
        Shape.read_string("#{self.class}#expanded_text", text)&.gsub(Regexp.union(replacements.keys.sort_by { |url| -url.length }), replacements)
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

      # Hide this reply, as the author of the post it replies to
      #
      # @api public
      # @return [Boolean] true if the reply is now hidden
      # @example Hide a reply
      #   reply.hide_reply
      def hide_reply
        self.class.hide_reply(self, client: client!)
      end

      # Show this reply after hiding it, as the author of the post it replies to
      #
      # @api public
      # @return [Boolean] true if the reply is no longer hidden
      # @example Show a hidden reply
      #   reply.unhide_reply
      def unhide_reply
        self.class.unhide_reply(self, client: client!)
      end

      private

      # The attributes that hold the full text and its entities
      #
      # A long post holds them in note_post, and any other post holds them itself.
      #
      # @api private
      # @return [Hash] the attributes
      def full = note_post || attrs

      # The shortened url of each link that holds one, and the URL it stands for
      # @api private
      # @return [Hash{String => String}] each shortened url and the HTML-escaped URL it stands for
      # @raise [InvalidAttribute] if a link holds a url, or an expanded_url beside a url, that is neither a String nor null
      def expansions = urls.reject { |link| link["url"].nil? }.to_h { |link| Utils.read("#{self.class}#expanded_text", link) { expansion(link) } }

      # The shortened url of a link, and the URL it stands for
      #
      # A link the API expanded to no URL stands for its url itself. The URL is HTML-escaped, as the text it goes into is.
      #
      # @api private
      # @param link [Hash] the link
      # @return [Array(String, String)] the shortened url and the HTML-escaped URL it stands for
      # @raise [KeyError] if the link has no url
      # @raise [ArgumentError] if the link names a URL that is not a String
      def expansion(link)
        url = link.fetch("url")
        expanded_url = link["expanded_url"] || url
        raise ArgumentError, "a link needs a url, and an expanded_url if any, that are Strings" unless [url, expanded_url].all?(String)

        [url, CGI.escapeHTML(expanded_url)]
      end
    end
  end

  # Alias for Post, the name the API gave a post before it named it a post
  # @api public
  Tweet = Post
end
