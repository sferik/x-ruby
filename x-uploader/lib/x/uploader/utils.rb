module X
  module Uploader
    # Helpers shared across the uploaders
    #
    # Internal to x-uploader: the uploaders call it rather than mix its methods into themselves, so a class that
    # includes an uploader gains none of them.
    #
    # @api private
    module Utils
      extend self

      # The lowercase extension of a file, without its dot
      #
      # @api private
      # @param file_path [String] the path to the file
      # @return [String] the extension
      # @example The extension of a file
      #   Uploader::Utils.extension("cat.JPG") # => "jpg"
      def extension(file_path) = File.extname(file_path).delete(".").downcase

      # The media identifier of an upload response or of an identifier
      #
      # @api private
      # @param media [Hash, String, Integer] the upload response, or the media identifier
      # @return [String] the media identifier
      # @raise [KeyError] if an upload response has no id
      # @example The identifier of uploaded media
      #   Uploader::Utils.media_id({"id" => "1880028106020515840"}) # => "1880028106020515840"
      def media_id(media) = media.is_a?(Hash) ? media.fetch("id").to_s : media.to_s
    end
  end
end
