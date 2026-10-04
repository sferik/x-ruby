# frozen_string_literal: true

require "yard"
require_relative "../../test_helper"

module X
  # The documentation YARD builds with the options of .yardopts, as rubydoc.info builds it, shows every public method of
  # every public class and module, those of the modules it includes or extends among them, and nothing that is private
  class DocumentationTest < Minitest::Test
    ROOT = File.expand_path("../../..", __dir__)
    LIB = File.join(ROOT, "lib", "")

    # The modules whose methods are public API of the classes that include or extend them, which are private constants
    MIXINS = %w[BatchFinders DirectMessageConversations Finders Identity Marshalling PostCollections PostCounts PostSearch
      PostWrites References Relationships Serialization UserCollections UserFinders ValueEquality ValueMarshalling].freeze

    # Methods a module that is included or extended defines, or that are another name of an attribute, which YARD
    # shows only when it resolves the module, shows it, and reads the name
    MIXED_IN = [[User, :class, :find], [User, :class, :current], [User, :instance, :followers], [User, :instance, :follows?],
      [User, :instance, :tweet_count], [Post, :class, :search], [Post, :class, :retweets_of_me], [Post, :instance, :quoted],
      [Post, :instance, :liked_by], [Resource, :instance, :==], [Resource, :instance, :to_json], [Trend, :instance, :eql?],
      [DirectMessage, :class, :create_group], [Space, :class, :find_all], [Resources::API, :instance, :find_user]].freeze

    # The command of YARD that builds the documentation, which builds no pages here. YARD sets the default encodings of
    # the process as it makes one, and they are set back, so that the tests after this one run as those before it do.
    def self.command
      encodings = [Encoding.default_external, Encoding.default_internal]
      verbose, $VERBOSE = $VERBOSE, nil
      YARD::CLI::Yardoc.new.tap { |yardoc| yardoc.generate = false }
    ensure
      Encoding.default_external, Encoding.default_internal = encodings
      $VERBOSE = verbose
    end

    # The verifier YARD shows an object by, having read the sources .yardopts names into its registry, which is done
    # once, since it reads every file of the gem
    def self.verifier
      @verifier ||= Dir.chdir(ROOT) do
        yardoc = command
        yardoc.parse_arguments
        YARD::Registry.clear
        YARD::Logger.instance.enter_level(YARD::Logger::ERROR) { YARD.parse(yardoc.files, yardoc.excluded) }
        yardoc.options.verifier
      end
    end

    def shown?(object) = self.class.verifier.call(object)

    def declared_here?(location) = location.to_a.first.to_s.start_with?(LIB)

    # The public classes and modules the gem declares, by reflection
    def namespaces(parent = X)
      declared = parent.constants(false).select { |name| declared_here?(parent.const_source_location(name)) }
      declared.map { |name| parent.const_get(name) }.grep(Module).flat_map { |mod| [mod, *namespaces(mod)] }
    end

    # The public methods the gem defines on a class or module, by reflection, each with its scope
    def public_methods_of(mod)
      {instance: mod, class: mod.singleton_class}.flat_map do |scope, owner|
        defined = owner.public_instance_methods.select { |name| declared_here?(owner.instance_method(name).source_location) }
        defined.map { |name| [scope, name] }
      end
    end

    # The object YARD documents a class or module as, with the registry read
    def documentation_of(mod)
      self.class.verifier
      YARD::Registry.at(mod.name)
    end

    # The methods the page of a class or module lists as its own, as the template of YARD does: its methods and those of
    # its mixins, less each that is hidden or that a hidden module defines
    def listed(namespace)
      namespace.meths(inherited: false, included: true).select { |method| shown?(method) && shown?(method.parent) }
    end

    # The methods the documentation shows for a class or module, on its page or on that of a superclass
    def documented(mod)
      ancestors = documentation_of(mod).inheritance_tree.reject { |ancestor| ancestor.is_a?(YARD::CodeObjects::Proxy) }
      ancestors.select { |ancestor| shown?(ancestor) }.flat_map { |ancestor| listed(ancestor) }.map { |method| [method.scope, method.name] }
    end

    # Everything the documentation shows: each class and module with a page, and what the page of one lists
    def shown
      self.class.verifier
      YARD::Registry.all.select { |object| shown?(object) && (object.is_a?(YARD::CodeObjects::NamespaceObject) || shown?(object.namespace)) }
    end

    def test_reading_the_documentation_leaves_the_encodings_of_the_process_as_they_were
      encodings = [Encoding.default_external, Encoding.default_internal]
      self.class.command

      assert_equal encodings, [Encoding.default_external, Encoding.default_internal]
    end

    def test_the_documentation_is_built_with_the_options_of_yardopts
      options = File.readlines(File.join(ROOT, ".yardopts"), chomp: true)

      assert_includes options, "--private"
      assert_includes options, "--hide-api private"
      assert_includes options, "--embed-mixins"
    end

    def test_every_public_class_and_module_is_documented
      undocumented = namespaces.reject { |mod| documentation_of(mod)&.then { |object| shown?(object) && object.tag(:api)&.text == "public" } }

      assert_empty undocumented
      assert_operator namespaces.size, :>=, 26
      assert_empty [User, Post, Resource, Cursor, Resources, Resources::API, MissingResource] - namespaces
    end

    def test_every_public_method_of_every_public_class_and_module_is_documented
      undocumented = namespaces.flat_map do |mod|
        (public_methods_of(mod) - documented(mod)).map { |scope, name| "#{mod}#{(scope == :class) ? "." : "#"}#{name}" }
      end

      assert_empty undocumented
    end

    def test_the_methods_a_class_is_given_by_the_modules_it_includes_and_extends_are_among_them
      MIXED_IN.each do |mod, scope, name|
        assert_includes public_methods_of(mod), [scope, name]
        assert_includes documented(mod), [scope, name]
      end
    end

    def test_nothing_tagged_private_is_documented
      assert_empty(shown.select { |object| object.tag(:api)&.text == "private" }.map(&:path))
      refute_nil YARD::Registry.at("X::Resources::Utils")
      refute shown?(YARD::Registry.at("X::Resources::Utils"))
    end

    def test_nothing_private_is_documented_but_the_modules_that_give_the_classes_their_public_methods
      hidden = shown.select { |object| object.visibility == :private }.map { |object| [object.path, object.type, object.tag(:api)&.text] }

      assert_equal MIXINS.map { |name| ["X::Resources::#{name}", :module, "semipublic"] }, hidden.sort
    end

    def test_every_constant_documented_is_a_public_constant
      constants = shown.select { |object| object.type == :constant }

      refute_empty constants
      assert_empty(constants.reject { |constant| Object.const_get(constant.namespace.path).constants(false).include?(constant.name) }.map(&:path))
    end
  end
end
