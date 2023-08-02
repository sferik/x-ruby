require "test_helper"

class VersionTest < Minitest::Test
  def test_major_version
    refute_nil X::Version.major
  end

  def test_minor_version
    refute_nil X::Version.minor
  end

  def test_patch_version
    refute_nil X::Version.patch
  end

  def test_to_h
    assert_kind_of Hash, X::Version.to_h
  end

  def test_to_a
    assert_kind_of Array, X::Version.to_a
  end

  def test_to_s
    assert_kind_of String, X::Version.to_s
  end

  def test_that_it_has_a_version_number
    refute_nil ::X::Version
  end
end
