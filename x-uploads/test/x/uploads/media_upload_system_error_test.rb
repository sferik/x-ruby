# frozen_string_literal: true

require "socket"
require_relative "../../test_helper"
require "x/uploads/account"
require "x/uploads/media_upload"

module X
  # Media the system refuses to read before a request is refused as media that cannot be read is, with no request
  class MediaUploadSystemErrorTest < Minitest::Test
    cover Uploads::MediaUpload
    cover Uploads::Account
    cover Uploads.const_get(:Source)

    PNG = "test/sample_files/sample.png"

    def setup
      @client = Client.new
    end

    # An IO that is not open on a file, whose read the system refuses
    def refusing_to_read(error)
      Object.new.tap { |io| io.define_singleton_method(:read) { raise error } }
    end

    def assert_refused_before_any_request(description, cause, &)
      error = assert_raises(InvalidMedia, &)

      assert_equal "#{description} cannot be read: #{reason_of(error.cause)}", error.message
      assert_kind_of cause, error.cause
      assert_not_requested :any, //
    end

    # The reason alone the system gives for one of its errors, and the message of any other
    def reason_of(cause) = cause.is_a?(SystemCallError) ? SystemCallError.new(cause.errno).message : cause.message

    # Upload a File open on the sample PNG that is closed as the method named is called
    def upload_closed_at(method)
      File.open(PNG, "rb") do |file|
        file.define_singleton_method(method) { |*arguments| close.then { super(*arguments) } }
        Uploads::MediaUpload.upload(file, client: @client)
      end
    end

    def test_a_socket_that_is_not_connected_is_refused_before_any_request
      server = TCPServer.new("127.0.0.1", 0)

      assert_refused_before_any_request("the media given", SystemCallError) { Uploads::MediaUpload.upload(server, client: @client) }
    ensure
      server&.close
    end

    def test_an_io_the_system_refuses_to_read_is_refused_before_any_request
      io = refusing_to_read(Errno::ENOTCONN)

      assert_refused_before_any_request("the media given", Errno::ENOTCONN) { Uploads::MediaUpload.upload(io, client: @client) }
    end

    def test_an_io_the_system_refuses_to_read_is_refused_before_a_chunked_upload_is_initialized
      io = refusing_to_read(Errno::EIO)

      assert_refused_before_any_request("the media given", Errno::EIO) { Uploads::MediaUpload.chunked_upload(io, client: @client) }
    end

    def test_an_io_the_system_refuses_to_read_is_refused_as_a_profile_image_before_any_request
      io = refusing_to_read(Errno::EIO)

      assert_refused_before_any_request("the media given", Errno::EIO) { Uploads::Account.update_profile_image(io, client: @client) }
    end

    def test_a_file_the_system_refuses_to_read_the_signature_of_is_refused_before_any_request
      File.stub(:binread, ->(*) { raise Errno::EIO }) do
        assert_refused_before_any_request(PNG, Errno::EIO) { Uploads::MediaUpload.upload(PNG, client: @client) }
      end
    end

    def test_a_file_the_system_refuses_to_read_whole_is_refused_before_the_request_that_sends_it
      whole = ->(*arguments) { arguments.one? ? raise(Errno::EIO) : File.read(*arguments, mode: "rb") }

      File.stub(:binread, whole) do
        assert_refused_before_any_request(PNG, Errno::EIO) { Uploads::MediaUpload.upload(PNG, client: @client) }
      end
    end

    def test_an_open_file_closed_before_the_system_says_what_it_is_open_on_is_refused_before_any_request
      assert_refused_before_any_request("the media given", IOError) { upload_closed_at(:stat) }
    end

    def test_an_open_file_closed_before_its_size_is_read_is_refused_before_any_request
      assert_refused_before_any_request(PNG, IOError) { upload_closed_at(:size) }
    end

    def test_an_open_file_closed_before_it_is_read_is_refused_before_any_request
      assert_refused_before_any_request(PNG, IOError) { upload_closed_at(:pread) }
    end

    def test_an_open_file_closed_by_another_thread_before_it_is_read_whole_is_refused_before_the_request_that_sends_it
      File.open(PNG, "rb") do |file|
        whole = file.size
        file.define_singleton_method(:pread) do |length, offset|
          Thread.new { close }.join if length == whole
          super(length, offset)
        end

        assert_refused_before_any_request(PNG, IOError) { Uploads::MediaUpload.upload(file, client: @client) }
      end
    end

    def test_a_file_deleted_before_its_size_is_read_is_refused_before_any_request
      File.stub(:size, ->(_path) { raise Errno::ENOENT }) do
        assert_refused_before_any_request(PNG, Errno::ENOENT) { Uploads::MediaUpload.upload(PNG, client: @client) }
      end
    end
  end
end
