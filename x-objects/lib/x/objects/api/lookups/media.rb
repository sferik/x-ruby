# frozen_string_literal: true

require_relative "../../media"

module X
  module Objects
    module API
      module Lookups
        # Look up media by media key
        # @api public
        module Media
          # Look up media by media key
          #
          # A post refers to its media by media key, and so does what an upload returns, so this reads the photo,
          # video, or animated GIF that was uploaded, with its URL and variants.
          #
          # @api public
          # @param media_key [String, X::Media] the media key, such as 3_1880028106020515840
          # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
          #   parameter builds media that is not hydrated, so hydrate fetches the rest
          # @return [X::Media, nil] the media, or nil if it was not found
          # @yieldparam problem [Problem] each problem the API reported
          # @example Look up media by media key
          #   client.find_media("3_1880028106020515840")
          # @example Look up media that was uploaded
          #   client.find_media(uploaded.media_key)
          def find_media(media_key, **params, &)
            X::Media.find(media_key, client: self, **params, &)
          end

          # Look up media by media key, raising if it is not found
          #
          # @api public
          # @param media_key [String, X::Media] the media key
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
end
