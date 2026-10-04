# frozen_string_literal: true

require "logger"
require "stringio"
require "tempfile"
require_relative "../../test_helper"

module X
  # The debug output of a client is checked when the client is built, rather than by the first request, which writes
  # to it: what takes no String with << is refused, and so is a String, which would be appended every request in
  # place of the file it names
  class ClientDebugOutputValidationTest < Minitest::Test
    include LocalServer

    cover_client
    cover Core.const_get(:SettingValidator)
    cover Core.const_get(:Connection)
    cover OAuth2Authorization

    INVALID = "debug_output must take a String with <<, as an IO, a StringIO, or a Logger does, or be nil, not %s"
    STRING = "debug_output must be an IO, such as $stderr or File.open(\"debug.log\", \"a\"), or a StringIO to collect it, not a String, " \
      "which names no file, and would be appended every request and response instead"

    def message_of(&) = assert_raises(ArgumentError, &).message

    def test_a_debug_output_that_does_not_respond_to_the_append_operator_is_refused_when_the_client_is_built
      messages = [true, false, :stderr, Object.new].map { |debug_output| message_of { Client.new(debug_output:) } }

      assert_equal(["a TrueClass", "a FalseClass", "a Symbol", "an Object"].map { |name| format(INVALID, name) }, messages)
    end

    def test_the_class_of_what_is_refused_is_named_with_its_article
      messages = [KeyError.new, IOError.new, Class.new.new].map { |debug_output| message_of { Client.new(debug_output:) } }

      assert_equal [format(INVALID, "a KeyError"), format(INVALID, "an IOError")], messages.first(2)
      assert_match(/, not a #<Class:0x\h+>\z/, messages.last)
    end

    def test_an_integer_whose_append_operator_shifts_it_is_refused
      messages = [1, 2**64].map { |debug_output| message_of { Client.new(debug_output:) } }

      assert_equal [format(INVALID, "an Integer")] * 2, messages
    end

    def test_a_proc_whose_append_operator_composes_it_is_refused
      messages = [proc { |line| line }, ->(line) { line }].map { |debug_output| message_of { Client.new(debug_output:) } }

      assert_equal [format(INVALID, "a Proc")] * 2, messages
    end

    def test_a_method_whose_append_operator_composes_it_is_refused
      assert_equal format(INVALID, "a Method"), message_of { Client.new(debug_output: $stderr.method(:write)) }
    end

    def test_a_string_is_refused_as_what_names_no_file
      assert_equal STRING, message_of { Client.new(debug_output: "debug.log") }
      assert_equal STRING, message_of { Client.new(debug_output: +"") }
    end

    def test_a_string_of_a_subclass_is_refused_as_a_string_is
      assert_equal STRING, message_of { Client.new(debug_output: Class.new(String).new("debug.log")) }
    end

    def test_the_error_of_a_string_holds_nothing_of_it
      refute_includes message_of { Client.new(debug_output: "SECRET") }, "SECRET"
    end

    def test_a_copy_of_a_client_refuses_what_a_client_does
      client = Client.new

      assert_equal [format(INVALID, "a TrueClass"), STRING], [true, "debug.log"].map { |debug_output| message_of { client.with(debug_output:) } }
    end

    def test_an_authorization_refuses_what_a_client_does
      messages = [true, "debug.log"].map do |debug_output|
        message_of { OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: "https://example.com/callback", debug_output:) }
      end

      assert_equal [format(INVALID, "a TrueClass"), STRING], messages
    end

    def test_the_client_of_an_authorization_refuses_it_before_the_code_is_exchanged
      authorization = OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: "https://example.com/callback", state: "state")

      assert_equal STRING, message_of { authorization.client("https://example.com/callback?code=CODE&state=state", debug_output: "debug.log") }
      assert_not_requested :any, //
    end

    def test_no_debug_output_is_allowed
      assert_nil Client.new(debug_output: nil).debug_output
    end

    def test_an_io_is_allowed
      Tempfile.create("debug") do |file|
        [$stderr, $stdout, file].each { |debug_output| assert_same debug_output, Client.new(debug_output:).debug_output }
      end
    end

    def test_what_else_takes_a_string_with_the_append_operator_is_allowed
      [StringIO.new, Logger.new(nil), []].each { |debug_output| assert_same debug_output, Client.new.with(debug_output:).debug_output }
    end

    def test_a_request_is_written_to_a_string_io
      output = StringIO.new
      requested(output)

      assert_includes output.string, "GET /2/users/me HTTP/1.1"
    end

    def test_a_request_is_written_to_an_array
      output = []
      requested(output)

      assert_includes output.join, "GET /2/users/me HTTP/1.1"
    end

    def test_a_request_is_written_to_a_logger
      log = StringIO.new
      requested(Logger.new(log))

      assert_includes log.string, "GET /2/users/me HTTP/1.1"
    end

    def test_a_request_is_written_to_a_file
      Tempfile.create("debug") do |file|
        requested(file)

        assert_includes file.tap(&:rewind).read, "GET /2/users/me HTTP/1.1"
      end
    end

    private

    # Send a request to a server on the loopback interface from a client that writes it to the debug output
    def requested(debug_output)
      with_local_connections([EMPTY_RESPONSE]) do |port, _requests|
        Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/2/", debug_output:).get("users/me")
      end
    end
  end
end
