require "securerandom"
require "x/core"
require_relative "invalid_media_type"
require_relative "validator"

module X
  module Uploader
    # Uploads profile images and banners to the X API v1.1
    # @api public
    module Account
      extend self

      # Base URL for X API v1.1 account endpoints
      V1_BASE_URL = "https://api.x.com/1.1/".freeze
      # Supported image extensions for profile uploads
      SUPPORTED_EXTENSIONS = %w[gif jpg jpeg png].freeze

      # Update the authenticating user's profile image
      #
      # @api public
      # @param file_path [String] the path to the image file
      # @param client [Client] the X API client
      # @param boundary [String] the multipart boundary
      # @return [Hash, nil] the updated user object
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [InvalidMediaType] if the file type is not supported
      # @example Update profile image from a file
      #   Uploader::Account.update_profile_image("avatar.png", client: client)
      def update_profile_image(file_path, client:, boundary: SecureRandom.hex)
        validate_file!(file_path)
        update_profile_image_binary(File.binread(file_path), client:, boundary:)
      end

      # Update the authenticating user's profile image from binary content
      #
      # @api public
      # @param content [String] the binary image content
      # @param client [Client] the X API client
      # @param boundary [String] the multipart boundary
      # @return [Hash, nil] the updated user object
      # @example Update profile image from binary content
      #   Uploader::Account.update_profile_image_binary(image_data, client: client)
      def update_profile_image_binary(content, client:, boundary: SecureRandom.hex)
        body = construct_multipart_body(field_name: "image", content:, boundary:)
        headers = {"Content-Type" => "multipart/form-data; boundary=#{boundary}"}
        v1_client(client).post("account/update_profile_image.json", body, headers:)
      end

      # Update the authenticating user's profile banner
      #
      # @api public
      # @param file_path [String] the path to the image file
      # @param client [Client] the X API client
      # @param width [Integer, nil] the width of the banner
      # @param height [Integer, nil] the height of the banner
      # @param offset_left [Integer, nil] the left offset of the banner
      # @param offset_top [Integer, nil] the top offset of the banner
      # @param boundary [String] the multipart boundary
      # @return [Hash, nil] nil on success (204 No Content)
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [InvalidMediaType] if the file type is not supported
      # @example Update profile banner from a file
      #   Uploader::Account.update_profile_banner("banner.png", client: client)
      # @example Update profile banner with dimensions
      #   Uploader::Account.update_profile_banner("banner.png", client: client, width: 1500, height: 500)
      def update_profile_banner(file_path, client:, width: nil, height: nil, offset_left: nil, offset_top: nil,
        boundary: SecureRandom.hex)
        validate_file!(file_path)
        update_profile_banner_binary(File.binread(file_path), client:, width:, height:, offset_left:, offset_top:,
          boundary:)
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
      # @param boundary [String] the multipart boundary
      # @return [Hash, nil] nil on success (204 No Content)
      # @example Update profile banner from binary content
      #   Uploader::Account.update_profile_banner_binary(image_data, client: client)
      def update_profile_banner_binary(content, client:, width: nil, height: nil, offset_left: nil, offset_top: nil,
        boundary: SecureRandom.hex)
        body = construct_banner_body(content:, width:, height:, offset_left:, offset_top:, boundary:)
        headers = {"Content-Type" => "multipart/form-data; boundary=#{boundary}"}
        v1_client(client).post("account/update_profile_banner.json", body, headers:)
      end

      private

      # Derive an API v1.1 client from a client
      # @api private
      # @param client [Client] the X API client
      # @return [Client] a client with the same credentials for the v1.1 API
      def v1_client(client)
        client.copy(base_url: V1_BASE_URL)
      end

      # Validate that the file exists and has a supported extension
      # @api private
      # @param file_path [String] the file path
      # @return [nil]
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [InvalidMediaType] if the file type is not supported
      def validate_file!(file_path)
        Validator.validate_file_path!(file_path)

        extension = File.extname(file_path).delete(".").downcase
        return if SUPPORTED_EXTENSIONS.include?(extension)

        raise InvalidMediaType, "Unsupported file type: #{extension}. Supported types: #{SUPPORTED_EXTENSIONS.join(", ")}"
      end

      # Construct multipart body for profile image upload
      # @api private
      # @param field_name [String] the form field name
      # @param content [String] the binary content
      # @param boundary [String] the multipart boundary
      # @return [String] the multipart body
      def construct_multipart_body(field_name:, content:, boundary:)
        "--#{boundary}\r\n" \
          "Content-Disposition: form-data; name=\"#{field_name}\"\r\n" \
          "Content-Type: application/octet-stream\r\n\r\n" \
          "#{content}\r\n" \
          "--#{boundary}--\r\n"
      end

      # Construct multipart body for profile banner upload with optional dimensions
      # @api private
      # @param content [String] the binary content
      # @param width [Integer, nil] the width
      # @param height [Integer, nil] the height
      # @param offset_left [Integer, nil] the left offset
      # @param offset_top [Integer, nil] the top offset
      # @param boundary [String] the multipart boundary
      # @return [String] the multipart body
      def construct_banner_body(content:, width:, height:, offset_left:, offset_top:, boundary:)
        body = ""
        body += multipart_field("width", width, boundary) if width
        body += multipart_field("height", height, boundary) if height
        body += multipart_field("offset_left", offset_left, boundary) if offset_left
        body += multipart_field("offset_top", offset_top, boundary) if offset_top
        body + construct_multipart_body(field_name: "banner", content:, boundary:)
      end

      # Create a multipart form field
      # @api private
      # @param name [String] the field name
      # @param value [Object] the field value
      # @param boundary [String] the multipart boundary
      # @return [String] the multipart field
      def multipart_field(name, value, boundary)
        "--#{boundary}\r\n" \
          "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n" \
          "#{value}\r\n"
      end
    end
  end
end
