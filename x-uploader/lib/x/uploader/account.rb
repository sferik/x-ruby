# frozen_string_literal: true

require "securerandom"
require "x/core"
require_relative "invalid_media_type"
require_relative "json_classes"
require_relative "multipart"
require_relative "validator"

module X
  module Uploader
    # Uploads profile images and banners to the X API v1.1
    #
    # Its methods can be called on the module, or on an instance of a class that includes it, which gains its public
    # methods alone. They post to the absolute URL of the API v1.1 endpoint with the client they are given, which
    # keeps the connection it holds to the host open for the requests that follow, rather than with a copy of it.
    #
    # @api public
    module Account
      extend self

      # Base URL for X API v1.1 account endpoints
      V1_BASE_URL = "https://api.x.com/1.1/"
      # URL of the endpoint that updates the profile image of the authenticating user
      PROFILE_IMAGE_URL = "#{V1_BASE_URL}account/update_profile_image.json".freeze
      # URL of the endpoint that updates the profile banner of the authenticating user
      PROFILE_BANNER_URL = "#{V1_BASE_URL}account/update_profile_banner.json".freeze
      # Supported image extensions for profile uploads
      SUPPORTED_EXTENSIONS = %w[gif jpg jpeg png].freeze

      # Update the authenticating user's profile image
      #
      # @api public
      # @param file_path [String, Pathname] the path to the image file
      # @param client [Client] the X API client
      # @return [Hash, nil] the updated user object
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the file is empty, which holds nothing to upload
      # @raise [InvalidMediaType] if the file type is not supported
      # @example Update profile image from a file
      #   Uploader::Account.update_profile_image("avatar.png", client: client)
      def update_profile_image(file_path, client:)
        Validator.validate_file_path!(file_path)
        Validator.validate_extension!(file_path, SUPPORTED_EXTENSIONS)
        update_profile_image_binary(File.binread(file_path), client:)
      end

      # Update the authenticating user's profile image from binary content
      #
      # @api public
      # @param content [String] the binary image content
      # @param client [Client] the X API client
      # @return [Hash, nil] the updated user object
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
      # @api public
      # @param file_path [String, Pathname] the path to the image file
      # @param client [Client] the X API client
      # @param width [Integer, nil] the width of the banner
      # @param height [Integer, nil] the height of the banner
      # @param offset_left [Integer, nil] the left offset of the banner
      # @param offset_top [Integer, nil] the top offset of the banner
      # @return [Hash, nil] nil on success (204 No Content)
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the file is empty, which holds nothing to upload
      # @raise [InvalidMediaType] if the file type is not supported
      # @example Update profile banner from a file
      #   Uploader::Account.update_profile_banner("banner.png", client: client)
      # @example Update profile banner with dimensions
      #   Uploader::Account.update_profile_banner("banner.png", client: client, width: 1500, height: 500)
      def update_profile_banner(file_path, client:, width: nil, height: nil, offset_left: nil, offset_top: nil)
        Validator.validate_file_path!(file_path)
        Validator.validate_extension!(file_path, SUPPORTED_EXTENSIONS)
        update_profile_banner_binary(File.binread(file_path), client:, width:, height:, offset_left:, offset_top:)
      end

      # Update the authenticating user's profile banner from binary content
      #
      # @api public
      # @param content [String] the binary image content
      # @param client [Client] the X API client
      # @param width [Integer, nil] the width of the banner
      # @param height [Integer, nil] the height of the banner
      # @param offset_left [Integer, nil] the left offset of the banner
      # @param offset_top [Integer, nil] the top offset of the banner
      # @return [Hash, nil] nil on success (204 No Content)
      # @example Update profile banner from binary content
      #   Uploader::Account.update_profile_banner_binary(image_data, client: client)
      def update_profile_banner_binary(content, client:, width: nil, height: nil, offset_left: nil, offset_top: nil)
        boundary = SecureRandom.hex
        body = Multipart.body("banner", content, boundary:, width:, height:, offset_left:, offset_top:)
        headers = Multipart.headers(boundary)
        client.post(PROFILE_BANNER_URL, body, headers:, **JSON_CLASSES)
      end
    end
  end
end
