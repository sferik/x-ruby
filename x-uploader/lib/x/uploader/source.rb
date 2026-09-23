# frozen_string_literal: true

require_relative "utils"

module X
  module Uploader
    # The media an upload reads, given as a file path or as an IO
    #
    # Media given as a String, a Pathname, or any other path to a file is read from that file, and media given as an
    # IO open on a file, such as a File or a Tempfile, is read through that IO, whether or not its name still leads
    # to the file, as it no longer does once a Tempfile is unlinked: either is read a chunk at a time, so that media of
    # any size uploads without being held in memory. Media given as any other IO, such as a StringIO, is read to its
    # end once, and held, since an IO that is not open on a file cannot be read again by position; it is given back
    # at the position it held when it can seek, so that the media can be checked and then uploaded.
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

      # The source of media given as a path that is not a String, or as an IO
      #
      # A path, such as a Pathname, which cannot seek, is read from the file it names, and an IO open on a file, which
      # can, through that IO. Any other IO is read to its end, such as a StringIO, or a pipe, whose path is nil.
      #
      # @api private
      # @param media [Pathname, IO, StringIO, Object] the path or the IO
      # @return [Source] the source
      # @raise [ArgumentError] if the media is neither a path nor an IO
      def self.named_or_read(media)
        named = media.respond_to?(:to_path)
        if named && !media.respond_to?(:seek)
          Path.new(media)
        elsif named && media.to_path
          Handle.new(media)
        elsif media.respond_to?(:read)
          buffered(media)
        else
          raise ArgumentError, "media must be a path or an IO that reads one, not #{media.class}"
        end
      end
      private_class_method :named_or_read

      # The source of media given as an IO that is not open on a file
      #
      # The IO is read from its position to its end, and given back at that position when it can seek, as a StringIO
      # can and a pipe cannot, so that what infers the type of the media leaves it to be uploaded.
      #
      # @api private
      # @param media [StringIO, IO, Object] the IO
      # @return [Buffer] the source
      def self.buffered(media)
        position = position_of(media)
        content = media.read.to_s.b
        media.seek(position) if position
        Buffer.new(content)
      end
      private_class_method :buffered

      # The position of an IO that can seek
      # @api private
      # @param media [StringIO, IO, Object] the IO
      # @return [Integer, nil] the position, or nil for an IO that cannot seek
      def self.position_of(media)
        media.pos if media.respond_to?(:seek)
      rescue SystemCallError
        nil
      end
      private_class_method :position_of

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

      # Media read through an IO open on a file, a chunk at a time
      #
      # The IO is read by position, from the start of the file, whatever position it holds, and is left at that
      # position. Seeking flushes what the IO has written, as reading its size does, so that is read with the rest. The file need not be named by the path the IO holds: an unlinked Tempfile is read, as is one
      # created anonymous, whose path is its directory, and which so names no file.
      #
      # @api private
      class Handle < Source
        # Initialize the source of media read through an IO open on a file
        # @api private
        # @param io [IO] the IO, which answers to_path
        # @return [Handle] the source
        # @example The source of a File
        #   Uploader::Source::Handle.new(File.open("cat.jpg", "rb"))
        def initialize(io)
          @io = io
          path = File.path(io)
          @name = path unless File.directory?(path)
          @mutex = Mutex.new
        end

        # Whether the media exists, which media open on a file always does
        # @api private
        # @return [Boolean] true
        def exist? = true

        # Whether the media can be read, which an IO open on a directory cannot
        # @api private
        # @return [Boolean] true if the IO is open on a file
        def readable? = @io.stat.file?

        # The size of the media in bytes
        # @api private
        # @return [Integer] the size in bytes
        def size = @io.size

        # The whole of the media
        # @api private
        # @return [String] the bytes of the media
        def content = read(size, 0)

        # A run of the media, which the chunks of an upload are read with, from any thread
        #
        # The chunks read through one IO, so they read it in turn, and each gives the IO back at the position it held.
        #
        # @api private
        # @param length [Integer] the number of bytes to read
        # @param offset [Integer] the byte to read from, which is within the media
        # @return [String] the bytes
        def read(length, offset)
          @mutex.synchronize do
            position = @io.pos
            begin
              @io.seek(offset)
              @io.read(length) #: String
            ensure
              @io.seek(position)
            end
          end
        end
      end

      # Media read from an IO that is not open on a file, and held until the upload has finished
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
