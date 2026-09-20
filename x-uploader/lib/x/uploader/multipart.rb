module X
  module Uploader
    # Builds the multipart form requests of the uploads
    #
    # Internal to x-uploader: the uploaders call it rather than mix its methods into themselves, so a class that
    # includes an uploader gains none of them.
    #
    # @api private
    module Multipart
      extend self

      # The headers of a multipart form request
      #
      # @api private
      # @param boundary [String] the multipart boundary
      # @return [Hash{String => String}] the content type, which names the boundary
      # @example The headers of a request
      #   Uploader::Multipart.headers("boundary") # => {"Content-Type" => "multipart/form-data; boundary=boundary"}
      def headers(boundary) = {"Content-Type" => "multipart/form-data; boundary=#{boundary}"}

      # The body of a multipart form request: any form fields, then the content uploaded
      #
      # @api private
      # @param name [String] the name of the field that holds the content
      # @param content [String] the content to upload
      # @param boundary [String] the multipart boundary
      # @param fields [Hash{Symbol => Object}] the form fields that come before the content, less any that are nil
      # @return [String] the multipart body
      # @example The body of one chunk of a video
      #   Uploader::Multipart.body("media", chunk, boundary: "boundary", segment_index: 0)
      def body(name, content, boundary:, **fields)
        fields.compact.map { |field, value| "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{field}\"\r\n\r\n#{value}\r\n" }.join +
          "--#{boundary}\r\n" \
          "Content-Disposition: form-data; name=\"#{name}\"\r\n" \
          "Content-Type: application/octet-stream\r\n\r\n" \
          "#{content}\r\n" \
          "--#{boundary}--\r\n"
      end
    end
    private_constant :Multipart
  end
end
