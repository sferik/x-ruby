# frozen_string_literal: true

require_relative "utils"

module X
  module Uploader
    # The media an upload reads, given as a file path or as an IO
    #
    # Media given as a String, a Pathname, or any other object that names a file, such as a File or a Tempfile, is
    # read from that file, a chunk at a time, so that media of any size uploads without being held in memory. Media
    # given as any other IO, such as a StringIO, is read to its end once, and held, since an IO that names no file
    # cannot be read again by position.
    #
    # Internal to x-uploader: the uploaders resolve what they were given to one of these, rather than read a path
    # themselves, so that a path and an IO upload the same way.
    #
    # @api private
    class Source
      # Bytes read from the start of media that names no file, enough for every signature {Signature} reads
      SNIFF_BYTES = 64
      private_constant :SNIFF_BYTES

      # The source of media given as a path or as an IO
      #
      # An IO that names a file is flushed first, so that what it has written reaches the file the upload reads.
      #
      # @api private
      # @param media [String, Pathname, IO, StringIO, Source] the path to the media, or an IO open on it
      # @return [Source] the source, which is what was given if that is already one
      # @raise [ArgumentError] if the media is neither a path nor an IO
      # @example The source of a file
      #   Uploader::Source.for("cat.jpg")
      # @example The source of media held in memory
      #   Uploader::Source.for(StringIO.new(bytes))
      def self.for(media)
        case media
        when Source then media
        when String then Path.new(media)
        else named_or_read(media)
        end
      end

      # The source of media given as an IO
      #
      # It is read from the file the IO names, when it names one.
      #
      # @api private
      # @param media [IO, StringIO, Object] the IO
      # @return [Source] the source
      # @raise [ArgumentError] if the media is neither a path nor an IO
      def self.named_or_read(media)
        return named(media) if media.respond_to?(:to_path)
        raise ArgumentError, "media must be a path or an IO that reads one, not #{media.class}" unless media.respond_to?(:read)

        Buffer.new(media.read.to_s.b)
      end
      private_class_method :named_or_read

      # The source of media given as an IO open on a file
      #
      # The IO is flushed, so that what it has written reaches the file the upload reads.
      #
      # @api private
      # @param media [IO] the IO
      # @return [Path] the source
      def self.named(media)
        media.flush if media.respond_to?(:flush)
        Path.new(media)
      end
      private_class_method :named

      # The name of the file the media was given as
      #
      # Media that names no file, which {Path} alone does, has none.
      #
      # @api private
      # @return [String, nil] the file name, or nil for media that names none
      # @example The name of media given as a path
      #   Uploader::Source.for("cat.jpg").name # => "cat.jpg"
      attr_reader :name

      # Whether the media names a file
      #
      # The media category and type of media that names one are inferred from that name.
      #
      # @api private
      # @return [Boolean] true if the media names a file
      # @example Check whether media names a file
      #   Uploader::Source.for(StringIO.new(bytes)).named? # => false
      def named? = !name.nil?

      # The media in words, for the message of an error it raises
      # @api private
      # @return [String] the file name, or a phrase for media that names none
      # @example Describe media held in memory
      #   Uploader::Source.for(StringIO.new(bytes)).description # => "the media given"
      def description = name || "the media given"

      # The lowercase extension of the file the media names
      #
      # It has no dot, and is "" for media that names no file.
      #
      # @api private
      # @return [String] the extension
      # @example The extension of media given as a path
      #   Uploader::Source.for("cat.JPG").extension # => "jpg"
      def extension = Utils.extension(name.to_s)

      # The bytes a signature is read from
      #
      # They are fewer than SNIFF_BYTES only if the media is shorter, and none at all if it is empty.
      #
      # @api private
      # @return [String] the leading bytes of the media
      # @example Read the signature of media
      #   Uploader::Source.for("cat.gif").sniff # => "GIF89a..."
      def sniff = read(SNIFF_BYTES, 0).to_s

      # Media read from the file it names, a chunk at a time
      # @api private
      class Path < Source
        # Initialize the source of media given as a path
        # @api private
        # @param path [String, Pathname] the path to the media
        # @return [Path] the source
        # @example The source of a file
        #   Uploader::Source::Path.new("cat.jpg")
        def initialize(path)
          @name = File.path(path)
        end

        # Whether the file exists
        #
        # An upload of media that is not there is refused.
        #
        # @api private
        # @return [Boolean] true if the file exists
        def exist? = File.exist?(name)

        # Whether the media can be read
        #
        # A file that is not there, or that is a directory, cannot be.
        #
        # @api private
        # @return [Boolean] true if the media is a file that can be read
        def readable? = File.file?(name)

        # The size of the media in bytes
        # @api private
        # @return [Integer] the size in bytes
        def size = File.size(name)

        # The whole of the media
        # @api private
        # @return [String] the bytes of the media
        def content = File.binread(name)

        # A run of the media, which the chunks of an upload are read with, from any thread
        # @api private
        # @param length [Integer] the number of bytes to read
        # @param offset [Integer] the byte to read from, which is within the media
        # @return [String] the bytes
        def read(length, offset) = File.binread(name, length, offset)
      end

      # Media read from an IO that names no file, and held until the upload has finished
      # @api private
      class Buffer < Source
        # Initialize the source of media read from an IO
        # @api private
        # @param content [String] the bytes read from the IO
        # @return [Buffer] the source
        # @example The source of media held in memory
        #   Uploader::Source::Buffer.new(bytes)
        def initialize(content)
          @content = content
        end

        # Whether the media exists, which media already read always does
        # @api private
        # @return [Boolean] true
        def exist? = true

        # Whether the media can be read, which media already read always can
        # @api private
        # @return [Boolean] true
        def readable? = true

        # The size of the media in bytes
        # @api private
        # @return [Integer] the size in bytes
        def size = @content.bytesize

        # The whole of the media
        # @api private
        # @return [String] the bytes of the media
        attr_reader :content

        # A run of the media, which the chunks of an upload are read with, from any thread
        # @api private
        # @param length [Integer] the number of bytes to read
        # @param offset [Integer] the byte to read from, which is within the media
        # @return [String] the bytes
        def read(length, offset)
          @content.byteslice(offset, length) #: String
        end
      end
    end
    private_constant :Source
  end
end
