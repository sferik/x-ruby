# frozen_string_literal: true

module X
  module Uploader
    # Reads the media type of media from the bytes it begins with
    #
    # Media is typed by its signature, the bytes every file of a type begins with, before the name of its file, so
    # that a file named as what it is not is typed as what it is. Only a type the API documents for an upload of a
    # media category it documents is read, so a glTF 3D model, which no category takes, is not among them, and only
    # one whose signature names it on its own, so SubRip subtitles, which begin with nothing a text file could not,
    # are not among them either.
    #
    # Internal to x-uploader: X::Uploader::MediaUpload reads a signature with it.
    #
    # @api private
    module Signature
      extend self

      # The brands an MP4 video names after the box type it begins with, which files of other types share with it: a
      # HEIF or AVIF image, and M4A audio, begin with that box type too, and name a brand of their own. The 3GPP and
      # 3GPP2 videos of phones, and the F4V, XAVC, and mobile MP4 videos of cameras and encoders, are MP4 files that
      # name a brand of their own too.
      MP4_BRANDS = ["isom", "iso2", "iso3", "iso4", "iso5", "iso6", "iso7", "iso8", "iso9", "mp41", "mp42", "avc1", "M4V ",
        "M4VH", "M4VP", "dash", "MSNV", "3gp4", "3gp5", "3gp6", "3g2a", "f4v ", "XAVC", "mmp4"].freeze

      # The media type each signature names, by the bytes that must appear at each offset, most specific first,
      # since the first signature that matches names the type: the brand of a QuickTime file or an MP4 video follows
      # the box type the two share, a WebP file is a RIFF file whose form is named eight bytes in, and an MPEG transport
      # stream, which begins with no header, is one whose first packets each begin with its sync byte, which a
      # transport stream of 188-byte packets begins with and one of the 192-byte packets of an M2TS file holds four
      # bytes in, after a timestamp. A signature of
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
        {4 => "ftypqt  ".b} => "video/quicktime",
        **MP4_BRANDS.to_h { |brand| [{4 => "ftyp#{brand}".b}, "video/mp4"] },
        {0 => [0xEF, 0xBB, 0xBF].pack("C*") + "WEBVTT"} => "text/vtt", # a byte order mark before the header
        {0 => "WEBVTT".b} => "text/vtt",
        {0 => "G".b, 188 => "G".b, 376 => "G".b} => "video/mp2t",
        {4 => "G".b, 196 => "G".b, 388 => "G".b} => "video/mp2t"
      }.freeze

      # The bytes of the EBML header a Matroska file begins with, which a WebM file, being Matroska, begins with too
      EBML = [0x1A, 0x45, 0xDF, 0xA3].pack("C*")
      # The DocType element of the EBML header of a WebM file: its identifier, the length of its value, and "webm", which
      # a Matroska file that is not WebM names "matroska" in place of. The header is the first thing in the file, so
      # its DocType is among the bytes a signature is read from.
      WEBM_DOC_TYPE = [0x42, 0x82, 0x84].pack("C*") + "webm".b
      private_constant :MP4_BRANDS, :SIGNATURES, :EBML, :WEBM_DOC_TYPE

      # The media type the signature of media names
      #
      # A Matroska file is WebM, which the API documents, only when its EBML header names webm as its DocType; the API
      # documents no type for any other Matroska file, such as an .mkv video, so its signature names none.
      #
      # @api private
      # @param bytes [String] the bytes the media begins with, as {Source#sniff} reads them
      # @return [String, nil] the media type, or nil if no signature names one
      # @example Read the media type of a PNG image
      #   Uploader::Signature.media_type("\x89PNG\r\n\x1A\n".b) # => "image/png"
      def media_type(bytes)
        return matroska_type(bytes) if matroska?(bytes)

        SIGNATURES.find { |magic, _| matches?(bytes, magic) }&.last
      end

      # Whether media begins with the EBML header of Matroska
      #
      # WebM is Matroska, so a WebM file begins with it too.
      #
      # @api private
      # @param bytes [String] the bytes the media begins with, as {Source#sniff} reads them
      # @return [Boolean] true if the media is Matroska
      # @example Tell a Matroska file
      #   Uploader::Signature.matroska?("\x1A\x45\xDF\xA3...".b) # => true
      def matroska?(bytes) = bytes.start_with?(EBML)

      private

      # The media type of a Matroska file, which is WebM when its DocType is webm
      # @api private
      # @param bytes [String] the bytes the media begins with, an EBML header first
      # @return [String, nil] video/webm, or nil for a Matroska file that is not WebM
      def matroska_type(bytes) = ("video/webm" if bytes.include?(WEBM_DOC_TYPE))

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
