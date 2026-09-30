# frozen_string_literal: true

require "x/core"
require_relative "invalid_media_type"
require_relative "multipart"
require_relative "source"
require_relative "validator"

module X
  module Uploader
    # Uploads profile images and banners to the X API v1.1
    #
    # Its methods can be called on the module, or on an instance of a class that includes it, which gains its public
    # methods alone. They post to the API v1.1 endpoint with the client they are given, which keeps the connection it
    # holds to the host open for the requests that follow, rather than with a copy of it. The endpoint is resolved
    # against the base URL of the client, in place of the version it names, so it is reached at the host the client
    # sends its other requests to, which its credentials are sent to, whether that is api.x.com, api.twitter.com,
    # or a proxy of the API.
    #
    # @api public
    module Account
      extend self

      # The API v1.1, relative to the base URL of a client, which names the version of the API it requests
      V1_BASE_URL = "../1.1/"
      # The endpoint that updates the profile image of the authenticating user, relative to the base URL of a client
      PROFILE_IMAGE_URL = "#{V1_BASE_URL}account/update_profile_image.json".freeze
      # The endpoint that updates the profile banner of the authenticating user, relative to the base URL of a client
      PROFILE_BANNER_URL = "#{V1_BASE_URL}account/update_profile_banner.json".freeze
      private_constant :V1_BASE_URL, :PROFILE_IMAGE_URL, :PROFILE_BANNER_URL

      # Update the authenticating user's profile image
      #
      # It returns nil, whatever the client answers with, as {update_profile_banner} does: the API v1.1 answers with
      # the user in its own shape, keyed as v1.1 keys it, which no object of these gems reads, since an X::User of
      # x-objects reads the users of the API v2 alone. Look the user up with the API v2 to read the image it now has.
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the image, or an IO that reads it, which is read from
      #   its start, as the media of an upload is
      # @param client [Client] the X API client
      # @return [void]
      # @raise [InvalidMedia] if the file does not exist
      # @raise [ArgumentError] if the media is neither a path nor an IO
      # @raise [InvalidMedia] if the media cannot be read, is empty, which holds nothing to upload, or is larger than
      #   the 700 kilobytes the API takes of a profile image
      # @raise [InvalidMediaType] if the media does not begin with the signature of a GIF, a JPEG, or a PNG, whatever
      #   its file is named
      # @example Update profile image from a file
      #   Uploader::Account.update_profile_image("avatar.png", client: client)
      # @example Update profile image from an image held in memory
      #   Uploader::Account.update_profile_image(StringIO.new(png), client: client)
      def update_profile_image(media, client:)
        source = Source.for(media)
        Validator.validate_profile_image!(source, Validator::MAX_PROFILE_IMAGE_BYTES, "a profile image")
        Multipart.post(client, PROFILE_IMAGE_URL, "image", source.content)
        nil
      end

      # Update the authenticating user's profile banner
      #
      # It returns nil, whatever the client answers with, since the endpoint answers with no content once the banner
      # is updated.
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the image, or an IO that reads it, which is read from
      #   its start, as the media of an upload is
      # @param client [Client] the X API client
      # @param width [Integer, nil] the width of the region of the image to use, in pixels, of at least 1
      # @param height [Integer, nil] the height of the region of the image to use, in pixels, of at least 1
      # @param offset_left [Integer, nil] the pixels by which the region is offset from the left, of at least 0
      # @param offset_top [Integer, nil] the pixels by which the region is offset from the top, of at least 0
      # @return [void]
      # @raise [InvalidMedia] if the file does not exist
      # @raise [ArgumentError] if the media is neither a path nor an IO, or a width, height, or offset is neither
      #   nil nor an Integer of the pixels it takes
      # @raise [InvalidMedia] if the media cannot be read, is empty, which holds nothing to upload, or is larger than
      #   the 5 megabytes X takes of a profile banner
      # @raise [InvalidMediaType] if the media does not begin with the signature of a GIF, a JPEG, or a PNG, whatever
      #   its file is named
      # @example Update profile banner from a file
      #   Uploader::Account.update_profile_banner("banner.png", client: client)
      # @example Update profile banner with dimensions
      #   Uploader::Account.update_profile_banner("banner.png", client: client, width: 1500, height: 500)
      def update_profile_banner(media, client:, width: nil, height: nil, offset_left: nil, offset_top: nil)
        Validator.validate_banner_region!(width:, height:, offset_left:, offset_top:)
        source = Source.for(media)
        Validator.validate_profile_image!(source, Validator::MAX_PROFILE_BANNER_BYTES, "a profile banner")
        Multipart.post(client, PROFILE_BANNER_URL, "banner", source.content, width:, height:, offset_left:, offset_top:)
        nil
      end
    end
  end
end
