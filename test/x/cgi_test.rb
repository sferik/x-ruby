require_relative "../test_helper"

module X
  class CGITest < Minitest::Test
    cover CGI

    def test_escape
      assert_equal "escape%20two%20spaces", X::CGI.escape("escape two spaces")
      assert_equal "foo%2Fbar", X::CGI.escape("foo/bar")
      assert_equal "foo%2Bbar", X::CGI.escape("foo+bar")
      assert_equal "%21%40%23%24", X::CGI.escape('!@#$')
    end

    def test_escape_params
      assert_equal "key1=value1&key2=value2", X::CGI.escape_params([%w[key1 value1], %w[key2 value2]])
      assert_equal "foo=bar%20baz", X::CGI.escape_params({"foo" => "bar baz"})
      assert_equal "a=1%2F2&b=3%2B4", X::CGI.escape_params({"a" => "1/2", "b" => "3+4"})
    end
  end
end
