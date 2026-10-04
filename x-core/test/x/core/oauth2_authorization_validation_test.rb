# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An authorization refuses, when it is built, the arguments it would build a URL X refuses with
  class OAuth2AuthorizationValidationTest < Minitest::Test
    cover OAuth2Authorization

    REDIRECT_URI = "https://example.com/callback"

    def authorization(**options)
      OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: REDIRECT_URI, **options)
    end

    def test_a_client_id_that_is_nil_or_empty_is_refused
      [nil, "", " "].each do |client_id|
        error = assert_raises(ArgumentError) { authorization(client_id:) }

        assert_equal "client_id is nil or empty. Pass the credential, which the authenticator cannot authenticate without", error.message
      end
    end

    def test_an_empty_client_secret_is_refused
      error = assert_raises(ArgumentError) { authorization(client_secret: "") }

      assert_equal "client_secret is empty. Pass the credential, or leave it out, since an empty one authenticates nothing", error.message
    end

    def test_a_redirect_uri_that_is_nil_or_empty_is_refused
      [nil, "", " ", :callback].each do |redirect_uri|
        error = assert_raises(ArgumentError) { authorization(redirect_uri:) }

        assert_equal "redirect_uri must be a String that is not empty; pass the URL X redirects the user back to, as registered for the app", error.message
      end
    end

    def test_a_redirect_uri_that_is_not_a_string_is_refused_as_what_is_not_one
      [URI("https://e.test/cb"), 42].each do |redirect_uri|
        error = assert_raises(ArgumentError) { authorization(redirect_uri:) }

        assert_equal "redirect_uri must be a String that is not empty; pass the URL X redirects the user back to, as registered for the app", error.message
      end
    end

    # What converts to a String, as a URI object of an app's own might, is not one, and is not held as one
    def test_a_redirect_uri_that_converts_to_a_string_is_refused
      redirect_uri = Object.new
      redirect_uri.define_singleton_method(:to_str) { REDIRECT_URI }
      error = assert_raises(ArgumentError) { authorization(redirect_uri:) }

      assert_equal "redirect_uri must be a String that is not empty; pass the URL X redirects the user back to, as registered for the app", error.message
    end

    def test_scopes_that_are_not_an_array_of_strings_are_refused
      error = assert_raises(ArgumentError) { authorization(scopes: "tweet.read users.read") }

      assert_equal 'scopes must be an Array of Strings that each name a scope, such as %w[tweet.read users.read offline.access], not "tweet.read users.read"', error.message
      [[:"tweet.read"], nil].each { |scopes| assert_raises(ArgumentError) { authorization(scopes:) } }
    end

    def test_a_string_that_names_no_scope_is_refused
      ["tweet.read users.read", "", "tweet\"read"].each do |scope|
        error = assert_raises(ArgumentError) { authorization(scopes: [scope]) }

        assert_includes error.message, "not #{[scope].inspect}"
      end
    end

    def test_the_scopes_are_a_frozen_copy_of_those_given
      scopes = +"tweet.read"
      given = [scopes]
      authorization = authorization(scopes: given)
      given << "users.read"
      scopes << ".more"

      assert_equal [%w[tweet.read], true, true], [authorization.scopes, authorization.scopes.frozen?, authorization.scopes.first.frozen?]
    end

    def test_a_base_url_that_is_not_one_a_client_takes_is_refused
      ["api.x.com/2/", "https://user:SECRET@api.x.com/2/", nil].each do |base_url|
        assert_raises(ArgumentError) { authorization(base_url:) }
      end
    end

    def test_an_empty_array_of_scopes_is_taken
      assert_empty authorization(scopes: []).scopes
    end

    # An Array of scopes of an app of its own
    class Scopes < Array; end

    def test_scopes_of_a_subclass_of_array_are_taken
      assert_equal %w[users.read], authorization(scopes: Scopes["users.read"]).scopes
    end
  end
end
