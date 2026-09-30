# frozen_string_literal: true

module X
  module Objects
    # Reads the media identifiers a new post or direct message attaches
    #
    # What an upload returns, media such as the media of another post, and a media identifier each name media, and
    # this reads the identifier the API takes from any of them.
    #
    # @api private
    module MediaIds
      # The pattern of a media key, which names the media identifier after the number of its type and an underscore
      MEDIA_KEY = /\A\d+_(\d+)\z/

      # The pattern of a media identifier the API takes: one to nineteen digits
      MEDIA_ID = /\A\d{1,19}\z/

      # The message of the error raised for something that is neither media nor the identifier of media
      NOT_MEDIA = "media is what an upload returned, media such as X::Media, a media key, or a media identifier, not %s"
      private_constant :MEDIA_KEY, :MEDIA_ID, :NOT_MEDIA

      extend self

      # Extract a media identifier from an upload, from media, or from a raw value
      #
      # What an upload returns is read with fetch, which a Hash answers and so does the uploaded media of
      # x-uploader, which this gem does not depend on. Media, such as the media of a post, is read from its media
      # key, which names the identifier, and so is a String that is a media key, such as the id of X::Media.
      #
      # @api private
      # @param value [#fetch, #media_key, String, Integer] what an upload returned, holding an id, media, a media key,
      #   or an identifier
      # @return [String] the media identifier
      # @raise [ArgumentError] if the value is none of them, or names an identifier the API would refuse
      def media_id_of(value)
        id = case value
        when String then value[MEDIA_KEY, 1] || value
        when Integer then value.to_s
        else value.respond_to?(:fetch) ? value.fetch("id").to_s : media_key_id(value)
        end
        id.match?(MEDIA_ID) ? id : raise(ArgumentError, format(NOT_MEDIA, value.inspect))
      end

      # The media identifier a media key names
      # @api private
      # @param media [#media_key, Object] the media
      # @return [String] the media identifier
      # @raise [ArgumentError] if the media has no media key that names an identifier
      def media_key_id(media)
        key = media.media_key if media.respond_to?(:media_key)
        key.to_s[MEDIA_KEY, 1] || raise(ArgumentError, format(NOT_MEDIA, media.inspect))
      end

      # The media identifiers of one upload or of several
      #
      # One upload needs no array around it, so a single value is read as a list of one, and nil, like an empty
      # list, as none.
      #
      # @api private
      # @param media_ids [Array, #fetch, Media, String, Integer, nil] what the uploads returned, media, or identifiers,
      #   one or many
      # @return [Array<String>] the media identifiers, empty for nil
      def media_ids_of(media_ids)
        case media_ids
        when nil then []
        when Array then media_ids.map { |media| media_id_of(media) }
        else [media_id_of(media_ids)]
        end
      end
    end
    private_constant :MediaIds
  end
end
