# frozen_string_literal: true

require_relative "../test_helper"
require "x/uploads/version"
require "x/streams/version"

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
      assert_equal VERSION, Uploads::VERSION
      assert_equal VERSION, Streams::VERSION
      assert_equal VERSION, Resources::VERSION
    end

    def test_x_core_asks_for_a_net_http_that_raises_net_open_timeout_for_a_connection_that_times_out_opening
      requirement = Gem::Specification.load(File.expand_path("../../x-core/x-core.gemspec", __dir__)).dependencies.find { |dependency| dependency.name.eql?("net-http") }.requirement

      assert_equal [false, true], %w[0.9.0 0.9.1].map { |version| requirement.satisfied_by?(Gem::Version.new(version)) }
    end

    def test_lockstep_gem_versions
      assert_equal X.gem_version, Core.gem_version
      assert_equal X.gem_version, Uploads.gem_version
      assert_equal X.gem_version, Streams.gem_version
      assert_equal X.gem_version, Resources.gem_version
    end
  end
end
