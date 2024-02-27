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
  end
end
