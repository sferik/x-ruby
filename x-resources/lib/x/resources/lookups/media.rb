# frozen_string_literal: true

require_relative "../batch_finders"
require_relative "../media"

module X
  module Resources
    module Lookups
      # Look up media by media key
      #
      # Internal to x-resources: X::Resources::API includes it, and its methods are public API of the client that
      # includes API, but the module is only how they are grouped, and some of them need the methods of another,
      # so include API rather than this module alone.
      #
      # @api semipublic
      module Media
        # Look up media by media key
        #
        # A post refers to its media by media key, and so does what an upload returns, so this reads the photo,
        # video, or animated GIF that was uploaded, with its URL and variants.
        #
        # @api public
        # @param media_key [String, X::Media, #media_key] the media key, such as 3_1880028106020515840, media, or what
        #   an upload returned
        # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
        #   parameter to leave some out builds media that is not hydrated, so hydrate fetches the rest
        # @return [X::Media, nil] the media, or nil if it was not found
        # @yieldparam problem [Problem] each problem the API reported
        # @example Look up media by media key
        #   client.find_media("3_1880028106020515840")
        # @example Look up media that was uploaded
        #   client.find_media(uploaded)
        def find_media(media_key, **params, &)
          X::Media.find(media_key, client: self, **params, &)
        end

        # Look up media by media key, in parallel batches
        #
        # @api public
        # @param media [Array<String, X::Media, #media_key>] the media keys, or the media, or what the uploads
        #   returned, whose keys are taken
        # @param concurrency [Integer] the number of batches looked up at once, which must be at least one; each is
        #   a request of up to 100 media keys, so a lower number spends a rate limit more slowly
        # @param params [Hash] query parameters merged over the default parameters; one that overrides a default
        #   field parameter builds media that is not hydrated, so hydrate fetches the rest
        # @return [Array<X::Media>] the media that was found
        # @raise [ArgumentError] if the concurrency is less than one
        # @yieldparam problem [Problem] each problem the API reported, such as a media key that was not found
        # @example Look up the media of a post
        #   client.find_all_media(post.media)
        # @example Look up media by media key
        #   client.find_all_media(%w[3_1880028106020515840 3_1880028106020515841])
        def find_all_media(media, concurrency: BatchFinders::DEFAULT_CONCURRENCY, **params, &)
          X::Media.find_all(media, client: self, concurrency:, **params, &)
        end

        # Look up media by media key, raising if it is not found
        #
        # @api public
        # @param media_key [String, X::Media, #media_key] the media key, media, or what an upload returned
        # @param params [Hash] query parameters merged over the default parameters
        # @return [X::Media] the media
        # @raise [MissingResource] if the media was not found
        # @example Look up media that must exist
        #   client.find_media!("3_1880028106020515840")
        def find_media!(media_key, **params)
          X::Media.find!(media_key, client: self, **params)
        end
      end
    end
  end
end
