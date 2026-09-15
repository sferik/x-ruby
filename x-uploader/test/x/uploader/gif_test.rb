require_relative "../../test_helper"
require "tmpdir"
require "x/uploader/gif"

module X
  class GifTest < Minitest::Test
    cover Uploader::Gif

    # A graphic control extension, as animations and transparent images carry
    CONTROL = "\x21\xF9\x04\x00\x0A\x00\x00\x00".b
    # A looping application extension, whose data spans two sub-blocks
    LOOP = "\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00".b

    def test_a_still_gif
      assert_instance_of FalseClass, animated?(gif(image))
      refute animated?(gif(CONTROL + image))
    end

    def test_an_animated_gif
      assert animated?(gif(LOOP + CONTROL + image + CONTROL + image))
    end

    def test_a_second_frame_after_a_local_color_table
      assert animated?(gif(image(local_table: 2) + image, global_table: nil))
    end

    def test_a_second_frame_after_image_data_in_several_sub_blocks
      assert animated?(gif(image(data: "\x02\xAA\xBB\x01\xCC\x00".b) + image, global_table: 5))
    end

    def test_color_table_sizes
      assert animated?(gif(image(local_table: 7) + image, global_table: 6))
      assert animated?(gif(image(local_table: 1) + image, global_table: 3))
    end

    def test_flag_bits_other_than_the_table_flag_add_no_table
      assert animated?(gif(image(extra_flags: 0x43) + image, global_table: nil, extra_flags: 0x77))
    end

    def test_the_trailer_ends_the_frames
      refute animated?(gif(image + "\x3B".b + image))
    end

    def test_truncated_and_empty_files
      refute animated?(gif(image)[0...-6])
      refute animated?("".b)
      refute animated?("GIF89a".b)
    end

    def test_real_files
      refute Uploader::Gif.animated?("test/sample_files/sample.gif")
      assert Uploader::Gif.animated?("test/sample_files/sample_animated.gif")
    end

    private

    def gif(blocks, global_table: 1, extra_flags: 0)
      flags = global_table ? 0x80 | global_table : extra_flags
      "GIF89a\x02\x00\x02\x00".b + [flags, 0, 0].pack("C3") + table(global_table) + blocks + "\x3B".b
    end

    def image(local_table: nil, data: "\x01\x55\x00".b, extra_flags: 0)
      flags = local_table ? 0x80 | local_table : extra_flags
      "\x2C\x00\x00\x00\x00\x02\x00\x02\x00".b + [flags].pack("C") + table(local_table) + "\x02".b + data
    end

    def table(size) = size ? "\x00".b * (3 << (size + 1)) : "".b

    def animated?(data)
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.gif")
        File.binwrite(path, data)
        Uploader::Gif.animated?(path)
      end
    end
  end
end
