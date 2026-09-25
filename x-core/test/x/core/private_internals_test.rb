# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # What one object of x-core reads of another is private, and read with __send__, since the signatures have no
  # protected methods, and would call a protected method public
  class PrivateInternalsTest < Minitest::Test
    def test_no_class_of_x_core_has_a_protected_method
      [Client, StreamingClient, Connection, OAuth2Authenticator].each do |klass|
        assert_empty klass.protected_instance_methods, "Expected #{klass} to have no protected methods"
      end
    end

    def test_what_a_copy_or_a_stream_reads_of_a_client_is_private
      %i[proxy_url settings share_authenticator oauth2_authenticator oauth2_authenticator_in_use].each do |name|
        assert_includes Client.private_instance_methods, name
      end
      assert_includes StreamingClient.private_instance_methods, :proxy_url
      assert_includes OAuth2Authenticator.private_instance_methods, :credentials
    end
  end
end
