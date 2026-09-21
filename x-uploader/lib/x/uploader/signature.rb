# frozen_string_literal: true

require_relative "invalid_media_type"

module X
  module Uploader
    # Reads the media type of media from the bytes it begins with
    #
    # Media given as a file is typed by the name of the file. Media given as an IO that names none, such as a
    # StringIO, is typed by its signature: the bytes every file of a type begins with. Only a type the API documents
    # for an upload is read, and only one whose signature names it on its own, so SubRip subtitles, which begin with
    # nothing a text file could not, are not among them.
    #
    # Internal to x-uploader: X::Uploader::MediaUpload reads a signature with it.
    #
    # @api private
    module Signature
      extend self

      # The media type each signature names, by the bytes that must appear at each offset, most specific first,
      # since the first signature that matches names the type: the brand of a QuickTime file follows the box type an
      # MP4 file shares with it, and a WebP file is a RIFF file whose form is named eight bytes in. A signature of
      # bytes above ASCII is packed from them, since a String literal of those bytes is not the UTF-8 this file is.
      SIGNATURES = {
        {0 => "GIF87a".b} => "image/gif",
        {0 => "GIF89a".b} => "image/gif",
        {0 => [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack("C*")} => "image/png", # \x89PNG\r\n\x1A\n
        {0 => [0xFF, 0xD8, 0xFF].pack("C*")} => "image/jpeg",
        {0 => "BM".b} => "image/bmp",
        {0 => "II*\x00".b} => "image/tiff",
        {0 => "MM\x00*".b} => "image/tiff",
        {0 => "RIFF".b, 8 => "WEBP".b} => "image/webp",
        {0 => [0x1A, 0x45, 0xDF, 0xA3].pack("C*")} => "video/webm", # the EBML header of Matroska
        {4 => "ftypqt  ".b} => "video/quicktime",
        {4 => "ftyp".b} => "video/mp4",
        {0 => "glTF".b} => "model/gltf-binary",
        {0 => [0xEF, 0xBB, 0xBF].pack("C*") + "WEBVTT"} => "text/vtt", # a byte order mark before the header
        {0 => "WEBVTT".b} => "text/vtt"
      }.freeze

      # The media category of posts each media type a signature names belongs to; any other type a signature names,
      # such as an image, belongs to DEFAULT_CATEGORY. The categories are the ones Validator takes.
      CATEGORIES = {
        "image/gif" => "tweet_gif", "text/vtt" => "subtitles", "video/mp2t" => "tweet_video",
        "video/mp4" => "tweet_video", "video/quicktime" => "tweet_video", "video/webm" => "tweet_video"
      }.freeze
      # The media category of media whose type belongs to none of its own
      DEFAULT_CATEGORY = "tweet_image"
      private_constant :SIGNATURES, :DEFAULT_CATEGORY

      # The media type the signature of media names
      #
      # @api private
      # @param bytes [String] the bytes the media begins with, as {Source#sniff} reads them
      # @return [String, nil] the media type, or nil if no signature names one
      # @example Read the media type of a PNG image
      #   Uploader::Signature.media_type("\x89PNG\r\n\x1A\n".b) # => "image/png"
      def media_type(bytes)
        SIGNATURES.find { |magic, _| matches?(bytes, magic) }&.last
      end

      # The media type the signature of media names, which one must name
      #
      # @api private
      # @param source [Source] the media
      # @return [String] the media type
      # @raise [InvalidMediaType] if no signature names the type of the media
      # @example Read the media type of media held in memory
      #   Uploader::Signature.media_type!(source) # => "image/png"
      def media_type!(source)
        media_type(source.sniff) ||
          raise(InvalidMediaType, "unable to determine the media type of #{source.description}: pass media_category")
      end

      # The media category of posts the signature of media that names no file gives it
      #
      # @api private
      # @param source [Source] the media
      # @return [String] the media category
      # @raise [InvalidMediaType] if no signature names the type of the media
      # @example Read the media category of media held in memory
      #   Uploader::Signature.media_category!(source) # => "tweet_image"
      def media_category!(source) = CATEGORIES.fetch(media_type!(source), DEFAULT_CATEGORY)

      private

      # Whether media begins with the bytes of a signature
      # @api private
      # @param bytes [String] the bytes the media begins with
      # @param magic [Hash{Integer => String}] the bytes the signature expects at each offset
      # @return [Boolean] true if the media matches the signature
      def matches?(bytes, magic)
        magic.all? { |offset, expected| bytes.byteslice(offset, expected.bytesize).eql?(expected) }
      end
    end
    private_constant :Signature
  end
end
