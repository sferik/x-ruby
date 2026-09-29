# frozen_string_literal: true

require "securerandom"
require "x/core"
require_relative "invalid_media_type"
require_relative "json_classes"
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
      # Supported image extensions for profile uploads
      SUPPORTED_EXTENSIONS = %w[gif jpg jpeg png].freeze
      private_constant :V1_BASE_URL, :PROFILE_IMAGE_URL, :PROFILE_BANNER_URL, :SUPPORTED_EXTENSIONS

      # Update the authenticating user's profile image
      #
      # It returns the user the API v1.1 answers with, deliberately as the Hash it parses to, keyed as v1.1 keys it,
      # such as screen_name rather than username: the API v2 has no endpoint that updates a profile image, and an
      # X::User of x-objects, which x-uploader does not load, reads the users of the API v2 alone.
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the image, or an IO that reads it, which is read from
      #   its start, as the media of an upload is
      # @param client [Client] the X API client
      # @return [Hash, nil] the updated user, as the API v1.1 answers with it, or nil for a response with no body
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the media is neither a path nor an IO, or is empty, which holds nothing to upload
      # @raise [InvalidMediaType] if the extension of the file, or the signature of media that names none, is not
      #   that of a GIF, a JPEG, or a PNG
      # @example Update profile image from a file
      #   Uploader::Account.update_profile_image("avatar.png", client: client)
      # @example Update profile image from an image held in memory
      #   Uploader::Account.update_profile_image(StringIO.new(png), client: client)
      def update_profile_image(media, client:)
        source = Source.for(media)
        Validator.validate_profile_image!(source, SUPPORTED_EXTENSIONS)
        update_profile_image_binary(source.content, client:)
      end

      # Update the authenticating user's profile image from binary content
      #
      # Like {update_profile_image}, it returns the user the API v1.1 answers with as the Hash it parses to.
      #
      # @api public
      # @param content [String] the binary image content
      # @param client [Client] the X API client
      # @return [Hash, nil] the updated user, as the API v1.1 answers with it, or nil for a response with no body
      # @example Update profile image from binary content
      #   Uploader::Account.update_profile_image_binary(image_data, client: client)
      def update_profile_image_binary(content, client:)
        boundary = SecureRandom.hex
        body = Multipart.body("image", content, boundary:)
        headers = Multipart.headers(boundary)
        client.post(PROFILE_IMAGE_URL, body, headers:, **JSON_CLASSES)
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
      # @param width [Integer, nil] the width of the banner
      # @param height [Integer, nil] the height of the banner
      # @param offset_left [Integer, nil] the left offset of the banner
      # @param offset_top [Integer, nil] the top offset of the banner
      # @return [nil] nil once the banner is updated, which the API answers with no content
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the media is neither a path nor an IO, or is empty, which holds nothing to upload
      # @raise [InvalidMediaType] if the extension of the file, or the signature of media that names none, is not
      #   that of a GIF, a JPEG, or a PNG
      # @example Update profile banner from a file
      #   Uploader::Account.update_profile_banner("banner.png", client: client)
      # @example Update profile banner with dimensions
      #   Uploader::Account.update_profile_banner("banner.png", client: client, width: 1500, height: 500)
      def update_profile_banner(media, client:, width: nil, height: nil, offset_left: nil, offset_top: nil)
        source = Source.for(media)
        Validator.validate_profile_image!(source, SUPPORTED_EXTENSIONS)
        update_profile_banner_binary(source.content, client:, width:, height:, offset_left:, offset_top:)
      end

      # Update the authenticating user's profile banner from binary content
      #
      # Like {update_profile_banner}, it returns nil, whatever the client answers with.
      #
      # @api public
      # @param content [String] the binary image content
      # @param client [Client] the X API client
      # @param width [Integer, nil] the width of the banner
      # @param height [Integer, nil] the height of the banner
      # @param offset_left [Integer, nil] the left offset of the banner
      # @param offset_top [Integer, nil] the top offset of the banner
      # @return [nil] nil once the banner is updated, which the API answers with no content
      # @example Update profile banner from binary content
      #   Uploader::Account.update_profile_banner_binary(image_data, client: client)
      def update_profile_banner_binary(content, client:, width: nil, height: nil, offset_left: nil, offset_top: nil)
        boundary = SecureRandom.hex
        body = Multipart.body("banner", content, boundary:, width:, height:, offset_left:, offset_top:)
        headers = Multipart.headers(boundary)
        client.post(PROFILE_BANNER_URL, body, headers:, **JSON_CLASSES)
        nil
      end
    end
  end
end
