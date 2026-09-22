# frozen_string_literal: true

require_relative "../test_helper"
require "x/uploader/version"

module X
  class MetaVersionTest < Minitest::Test
    def test_that_it_has_a_version_number
      refute_nil VERSION
    end

    def test_version_string
      assert_kind_of String, VERSION
    end

    def test_version_frozen
      assert_predicate VERSION, :frozen?
    end

    def test_version_file
      assert_equal File.read(File.expand_path("../../VERSION", __dir__)).strip, VERSION
    end

    def test_gem_version
      assert_kind_of Gem::Version, X.gem_version
    end

    def test_gem_version_reads_version
      assert_equal VERSION, X.gem_version.to_s
    end

    def test_lockstep_versions
      assert_equal VERSION, Core::VERSION
      assert_equal VERSION, Uploader::VERSION
      assert_equal VERSION, Objects::VERSION
    end

    def test_lockstep_gem_versions
      assert_equal X.gem_version, Core.gem_version
      assert_equal X.gem_version, Uploader.gem_version
      assert_equal X.gem_version, Objects.gem_version
    end
  end
end
