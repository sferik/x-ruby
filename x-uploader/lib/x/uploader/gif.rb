# frozen_string_literal: true

module X
  module Uploader
    # Tells an animated GIF from a still one by reading its blocks, without decoding any image
    # @api public
    module Gif
      extend self

      # Size in bytes of the header and logical screen descriptor
      HEADER_SIZE = 13
      # Byte that introduces an extension block
      EXTENSION_INTRODUCER = 0x21
      # Byte that introduces an image
      IMAGE_SEPARATOR = 0x2C
      # Size in bytes of an image descriptor, counting its separator
      IMAGE_DESCRIPTOR_SIZE = 10
      private_constant :HEADER_SIZE, :EXTENSION_INTRODUCER, :IMAGE_SEPARATOR, :IMAGE_DESCRIPTOR_SIZE

      # Check whether a GIF file holds more than one frame
      #
      # @api public
      # @param file_path [String, Pathname] the path to the GIF file
      # @return [Boolean] true if the GIF has a second frame
      # @example Check whether a GIF is animated
      #   Uploader::Gif.animated?("cat.gif") # => true
      def animated?(file_path)
        data = File.binread(file_path)
        position = skip_color_table(HEADER_SIZE, data.getbyte(10).to_i)
        frames = 0
        while (block = data.getbyte(position))
          frames += 1 if block.eql?(IMAGE_SEPARATOR)
          return true if frames > 1

          position = after_block(data, position, block)
        end
        false
      end

      private

      # The position after a block, or the end of the data after the last block
      # @api private
      # @param data [String] the GIF data
      # @param position [Integer] the position of the block
      # @param block [Integer] the byte that introduces the block
      # @return [Integer] the position after the block
      def after_block(data, position, block)
        case block
        when EXTENSION_INTRODUCER then skip_sub_blocks(data, position + 2)
        when IMAGE_SEPARATOR
          skip_sub_blocks(data, skip_color_table(position + IMAGE_DESCRIPTOR_SIZE, data.getbyte(position + 9).to_i) + 1)
        else data.bytesize
        end
      end

      # The position after a color table, if the flags say one follows
      # @api private
      # @param position [Integer] the position where a color table would start
      # @param flags [Integer] the packed flags of the descriptor, zero when the data ends before them
      # @return [Integer] the position after the color table
      def skip_color_table(position, flags)
        flags.anybits?(0x80) ? position + (3 << ((flags & 7) + 1)) : position
      end

      # The position after a run of data sub-blocks and its terminator
      # @api private
      # @param data [String] the GIF data
      # @param position [Integer] the position of the first sub-block
      # @return [Integer] the position after the terminator
      def skip_sub_blocks(data, position)
        while (size = data.getbyte(position).to_i).positive?
          position += size + 1
        end
        position + 1
      end
    end
  end
end
