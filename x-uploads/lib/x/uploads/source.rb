# frozen_string_literal: true

require_relative "invalid_media"
require_relative "utils"

module X
  module Uploads
    # The media an upload reads, given as a file path or as an IO
    #
    # Media given as a String, a Pathname, or any other path to a file is read from that file, and media given as an
    # IO open on a file, such as a File or a Tempfile, is read through that IO, whether or not its name still leads
    # to the file, as it no longer does once a Tempfile is unlinked: either is read a chunk at a time, so that media of
    # any size uploads without being held in memory. Media given as any other IO, such as a StringIO, is read once,
    # and held, since an IO that is not open on a file cannot be read again by position. An IO that can seek, as a
    # File and a StringIO can, is read from its start, whatever position it holds, and given back at that position,
    # so that the media can be checked and then uploaded, and a pipe, which cannot, is read from where it is.
    #
    # Internal to x-uploads: the uploaders resolve what they were given to one of these, rather than read a path
    # themselves, so that a path and an IO upload the same way.
    #
    # @api private
    class Source
      # Bytes read from the start of media that names no file, enough for every signature {Signature} reads
      SNIFF_BYTES = 512
      # The bytes a path of media is not written with, but its contents may be: a path holds no NUL byte, and names
      # no file with a line break in any use an upload is meant for, while an image read with File.binread holds a
      # NUL byte, and subtitles a line break
      CONTENT_BYTES = /[\0\n]/
      # The message of the error raised for the contents of media given where its path belongs
      NOT_A_PATH = "media must be a path to the media, or an IO that reads it, such as a StringIO, not the contents " \
        "of the media: a String that holds a NUL byte or a line break names no file"
      # The paths Ruby gives the standard streams, which name no file, even when a stream reads one, as $stdin
      # redirected from a file does
      STREAM_PATHS = %w[<STDIN> <STDOUT> <STDERR>].freeze
      # The words for media that names no file, in the message of an error it raises
      UNNAMED = "the media given"
      private_constant :SNIFF_BYTES, :CONTENT_BYTES, :NOT_A_PATH, :STREAM_PATHS, :UNNAMED

      # The source of media given as a path or as an IO
      #
      # An IO that names a file is flushed first, so that what it has written reaches the file the upload reads.
      #
      # A String is a path, so one that holds a NUL byte or a line break, as the contents of media given in its place
      # do, such as the bytes of an image or the text of subtitles, raises, rather than be looked for as a file named
      # by all of it.
      #
      # @api private
      # @param media [String, Pathname, IO, StringIO, Source] the path to the media, or an IO open on it
      # @return [Source] the source, which is what was given if that is already one
      # @raise [ArgumentError] if the media is neither a path nor an IO, or is a String that holds the contents of
      #   media rather than a path
      # @raise [InvalidMedia] if the media is an IO that cannot be read, or one the system cannot say what it is open
      #   on
      # @example The source of a file
      #   Uploads::Source.for("cat.jpg")
      # @example The source of media held in memory
      #   Uploads::Source.for(StringIO.new(bytes))
      def self.for(media)
        case media
        when Source then media
        when String then media.b.match?(CONTENT_BYTES) ? raise(ArgumentError, NOT_A_PATH) : Path.new(media)
        else named_or_read(media)
        end
      end

      # The source of media given as a path that is not a String, or as an IO
      #
      # A path, such as a Pathname, which cannot seek, is read from the file it names, as is a File or a Tempfile that
      # was closed, which can no longer be read through, and an IO open on a file, which can, through that IO, as
      # $stdin is when it is redirected from a file. Any other IO is read to its end, such as a StringIO, or a pipe,
      # whose path is nil, or $stdin reading a pipe or a terminal: an IO open on something that is not a file or a
      # directory, such as a pipe, cannot be read by position, as a file is. One whose path is nil that was closed,
      # such as a pipe, then raises InvalidMedia, as it cannot be read.
      #
      # @api private
      # @param media [Pathname, IO, StringIO, Object] the path or the IO
      # @return [Source] the source
      # @raise [ArgumentError] if the media is neither a path nor an IO
      # @raise [InvalidMedia] if the media is an IO that cannot be read, or one the system cannot say what it is open
      #   on
      def self.named_or_read(media)
        named = media.respond_to?(:to_path) && media.to_path
        if named && path_alone?(media)
          Path.new(media)
        elsif named && on_file?(media)
          Handle.new(media)
        elsif media.respond_to?(:read)
          buffered(media)
        else
          raise ArgumentError, "media must be a path or an IO that reads one, not #{media.class}"
        end
      end
      private_class_method :named_or_read

      # Check whether media that names a file can be read from that name alone
      # @api private
      # @param media [Pathname, IO] the path, or the IO, which has a path
      # @return [Boolean] true if the media cannot seek, as a path cannot, or is an IO that was closed
      def self.path_alone?(media) = !media.respond_to?(:seek) || (media.respond_to?(:closed?) && media.closed?)
      private_class_method :path_alone?

      # Check whether an IO is open on a file or a directory, which a Handle reads
      # @api private
      # @param media [IO] the IO, which has a path
      # @return [Boolean] true if the IO is open on a file or a directory, rather than a pipe, a device, or a socket
      # @raise [InvalidMedia] if the system cannot say what the IO is open on, or the IO was closed meanwhile
      def self.on_file?(media)
        reading(UNNAMED) do
          stat = media.stat
          stat.file? || stat.directory?
        end
      end
      private_class_method :on_file?

      # The source of media given as an IO that is not open on a file
      #
      # An IO that can seek, as a StringIO can, is read from its start, as a File is, whatever position it holds, such
      # as the end it is left at once it has been written to, and is given back at that position, so that what infers
      # the type of the media leaves it to be uploaded. One that cannot, as a pipe cannot, is read from where it is to
      # its end. An IO is put in binary mode first, since media is bytes, and a pipe or $stdin reads in text mode on
      # Windows, which would turn each CRLF of the media, such as the one in the signature of a PNG, into a line feed.
      # An IO that cannot be read, as a closed StringIO or one open for writing alone cannot, raises InvalidMedia, as
      # a File that cannot be read does when the upload checks it, and so does one the system refuses to read, as it
      # does a socket that is not connected, with the error of the system as its cause.
      #
      # @api private
      # @param media [StringIO, IO, Object] the IO
      # @return [Buffer] the source
      # @raise [InvalidMedia] if the IO cannot be read
      def self.buffered(media)
        reading(UNNAMED) do
          position = position_of(media)
          media.binmode if media.is_a?(IO)
          Buffer.new(read_whole(media, position))
        end
      end
      private_class_method :buffered

      # Read media before a request, raising InvalidMedia if it cannot be read
      #
      # What an upload reads of its media before it sends a request, what the media is open on, its size, its
      # signature, and the whole of media sent in a single request or held, is read with it, so that a file deleted
      # once the upload has checked it, a disk that fails, or an IO closed while it is read, as by another thread,
      # raises InvalidMedia, as media that cannot be read does, with the error as its cause. The message gives the
      # reason of an error of the system bare, as "No such file or directory", without the function of Ruby and the
      # path that Ruby adds to it, since the message names the media already, and that of any other error as it is.
      # The chunks of an upload are read without it, since a chunk that cannot be read fails an upload that is already
      # initialized, with the error as the cause of that.
      #
      # @api private
      # @param description [String] the media in words, which the message of the error begins with
      # @yield reads the media
      # @return [Object] what the block returns
      # @raise [InvalidMedia] if the read raises an IOError, as that of a closed IO, or an error of the system
      # @example Read the size of a file
      #   Uploads::Source.reading("cat.jpg") { File.size("cat.jpg") }
      def self.reading(description)
        yield
      rescue IOError, SystemCallError => e
        errno = e.errno if e.is_a?(SystemCallError)
        raise InvalidMedia, "#{description} cannot be read: #{errno ? SystemCallError.new(errno) : e}"
      end

      # Read an IO to its end, from its start if it can seek
      #
      # An IO that can seek is given back at its position, even if reading it raises.
      #
      # @api private
      # @param media [StringIO, IO, Object] the IO
      # @param position [Integer, nil] the position of the IO, or nil for an IO that cannot seek
      # @return [String] the bytes read
      def self.read_whole(media, position)
        media.seek(0) if position
        media.read.to_s.b
      ensure
        media.seek(position) if position
      end
      private_class_method :read_whole

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
      #   Uploads::Source.for("cat.jpg").name # => "cat.jpg"
      attr_reader :name

      # The media in words, for the message of an error it raises
      # @api private
      # @return [String] the file name, or a phrase for media that names none
      # @example Describe media held in memory
      #   Uploads::Source.for(StringIO.new(bytes)).description # => "the media given"
      def description = name || UNNAMED

      # The lowercase extension of the file the media names
      #
      # It has no dot, and is "" for media that names no file.
      #
      # @api private
      # @return [String] the extension
      # @example The extension of media given as a path
      #   Uploads::Source.for("cat.JPG").extension # => "jpg"
      def extension = Utils.extension(name.to_s)

      # The bytes a signature is read from
      #
      # They are fewer than SNIFF_BYTES only if the media is shorter, and none at all if it is empty.
      #
      # @api private
      # @return [String] the leading bytes of the media
      # @raise [InvalidMedia] if the system refuses to read the media, or it was closed meanwhile
      # @example Read the signature of media
      #   Uploads::Source.for("cat.gif").sniff # => "GIF89a..."
      def sniff = reading { read(SNIFF_BYTES, 0).to_s }

      # Media read from the file it names, a chunk at a time
      # @api private
      class Path < Source
        # Initialize the source of media given as a path
        # @api private
        # @param path [String, Pathname] the path to the media
        # @return [Path] the source
        # @example The source of a file
        #   Uploads::Source::Path.new("cat.jpg")
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
        # A file that is not there, that is a directory, or that the process has no permission to read, cannot be.
        #
        # @api private
        # @return [Boolean] true if the media is a file that can be read
        def readable? = File.file?(name) && File.readable?(name)

        # The size of the media in bytes
        #
        # It is read once, when first asked, so that an upload checks, declares, and appends the same number of bytes,
        # whatever the file does meanwhile.
        #
        # @api private
        # @return [Integer] the size in bytes
        # @raise [InvalidMedia] if the system refuses to read the size of the file
        def size = @size ||= reading { File.size(name) }

        # The whole of the media
        # @api private
        # @return [String] the bytes of the media
        # @raise [InvalidMedia] if the system refuses to read the file
        def content = reading { File.binread(name) }

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
      # position. Reading by position flushes what the IO has written, as reading its size does, so that is read with
      # the rest.
      # The file need not be named by the path the IO holds: an unlinked Tempfile is read, as is one created anonymous,
      # whose path is its directory, and $stdin redirected from a file, whose path is "<STDIN>", neither of which so
      # names a file.
      #
      # @api private
      class Handle < Source
        # Initialize the source of media read through an IO open on a file
        # @api private
        # @param io [IO] the IO, which answers to_path
        # @return [Handle] the source
        # @example The source of a File
        #   Uploads::Source::Handle.new(File.open("cat.jpg", "rb"))
        def initialize(io)
          @io = io
          path = File.path(io)
          @name = path unless STREAM_PATHS.include?(path) || File.directory?(path)
          @mutex = Mutex.new
        end

        # Whether the media exists, which media open on a file always does
        # @api private
        # @return [Boolean] true
        def exist? = true

        # Whether the media can be read: the IO is open on a file, and open for reading
        # @api private
        # @return [Boolean] true if the IO is open on a file for reading
        # @raise [InvalidMedia] if the system cannot say what the IO is open on, or the IO was closed meanwhile
        def readable? = reading { @io.stat.file? && open_for_reading? }

        # The size of the media in bytes
        #
        # A File or a Tempfile reads it with size, which flushes what it has written first, and an IO that answers no
        # size, as $stdin does, from the file it is open on. It is read once, when first asked, so that an upload
        # checks, declares, and appends the same number of bytes, whatever the file does meanwhile.
        #
        # @api private
        # @return [Integer] the size in bytes
        # @raise [InvalidMedia] if the system refuses to read the size of the file, or the IO was closed meanwhile
        def size = @size ||= reading { @io.respond_to?(:size) ? @io.size : @io.stat.size }

        # The whole of the media
        # @api private
        # @return [String] the bytes of the media
        # @raise [InvalidMedia] if the system refuses to read the file, or the IO was closed meanwhile
        def content = reading { read(size, 0) }

        # A run of the media, which the chunks of an upload are read with, from any thread
        #
        # It is read at its offset with pread, which leaves the position of the IO alone, so that uploads of one IO,
        # and code of the caller's own that reads it meanwhile, never read where another moved it to. An IO that cannot
        # pread, as one on Windows cannot, is read by seeking to the offset, with the chunks of the upload in turn,
        # and each gives the IO back at the position it held.
        #
        # @api private
        # @param length [Integer] the number of bytes to read
        # @param offset [Integer] the byte to read from, which is within the media
        # @return [String] the bytes, which are fewer than length, or none, if the file has fewer past the offset
        def read(length, offset)
          return seek_and_read(length, offset) unless @io.respond_to?(:pread)

          @io.pread(length, offset)
        rescue EOFError
          ""
        end

        private

        # Read a run of the media by seeking to its offset
        #
        # The IO is given back at the position it held.
        #
        # @api private
        # @param length [Integer] the number of bytes to read
        # @param offset [Integer] the byte to read from
        # @return [String] the bytes, or none if the file ends at the offset
        def seek_and_read(length, offset)
          @mutex.synchronize do
            position = @io.pos
            begin
              @io.seek(offset)
              @io.read(length).to_s
            ensure
              @io.seek(position)
            end
          end
        end

        # Whether the IO is open for reading, told by reading nothing from it
        # @api private
        # @return [Boolean] true if the IO can be read
        def open_for_reading?
          @io.read(0)
          true
        rescue IOError
          false
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
        #   Uploads::Source::Buffer.new(bytes)
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

      private

      # Read media before a request, raising InvalidMedia if it cannot be read
      # @api private
      # @yield reads the media
      # @return [Object] what the block returns
      # @raise [InvalidMedia] if the read raises an IOError, as that of a closed IO, or an error of the system
      def reading(&) = Source.reading(description, &)
    end
    private_constant :Source
  end
end
