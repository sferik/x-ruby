# frozen_string_literal: true

require_relative "../test_helper"

module X
  # x-core, x-resources, x-uploads, and x-streams are separate gems, and a client is built of all four, so a method
  # one of them adds within 1.x must take the name of no method of another. A method of X::Resources::API,
  # X::Uploads::API, or X::Streams::API, which X::Client includes, takes the place of a method of the same name in a
  # module of x-core that X::Client includes before them, and a method X::Client defines itself takes the place of
  # theirs, so a private helper of either side that the other came to name would be called by code that meant the
  # other one, and would break every request. So X::Client keeps no private methods but initialize, and no name is
  # shared either way.
  class ClientMethodNamesTest < Minitest::Test
    INCLUDED_APIS = [Resources::API, Uploads::API, Streams::API].freeze

    def test_a_client_has_no_private_method_of_x_core_but_initialize
      assert_equal %i[initialize], x_core_ancestors.flat_map { |ancestor| ancestor.private_instance_methods(false) }.sort
    end

    def test_no_method_of_an_included_api_takes_the_place_of_a_method_of_x_core
      INCLUDED_APIS.each do |api|
        below = x_core_ancestors.drop(1)

        assert_empty methods_of(api) & own_methods_of(below), "Expected #{api} to name no method of #{below.join(", ")}"
      end
    end

    def test_no_method_of_the_client_takes_the_place_of_a_method_of_an_included_api
      INCLUDED_APIS.each do |api|
        assert_empty own_methods_of([Client]) & methods_of(api), "Expected X::Client to name no method of #{api}"
      end
    end

    private

    # X::Client and the modules of x-core it includes, in the order a method is looked up in them
    def x_core_ancestors
      Client.ancestors - Object.ancestors - INCLUDED_APIS.flat_map(&:ancestors)
    end

    # The public, protected, and private methods an included API gives a client, with those of the modules it includes
    def methods_of(api) = api.instance_methods + api.private_instance_methods

    # The public, protected, and private methods the modules or classes define themselves
    def own_methods_of(ancestors)
      ancestors.flat_map { |ancestor| ancestor.instance_methods(false) + ancestor.private_instance_methods(false) }
    end
  end
end
