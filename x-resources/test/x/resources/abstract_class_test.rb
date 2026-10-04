# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Resources
    class AbstractClassTest < Minitest::Test
      cover Resources.const_get(:AbstractClass)

      def setup
        @base = Class.new do
          extend Resources.const_get(:AbstractClass)

          def self.from_id(id) = new(id)
          def self.from_response(body) = new(body.fetch("id"))
          private_class_method :new, :from_id, :from_response

          attr_reader :id

          def initialize(id) = @id = id
        end
      end

      def test_the_class_that_extends_it_builds_nothing
        assert_raises(NoMethodError) { @base.new(1) }
        assert_raises(NoMethodError) { @base.from_id(1) }
        assert_raises(NoMethodError) { @base.from_response({"id" => 1}) }
      end

      def test_a_class_that_descends_from_it_builds
        subclass = Class.new(@base)

        assert_equal [1, 2, 3], [subclass.new(1).id, subclass.from_id(2).id, subclass.from_response({"id" => 3}).id]
        assert_instance_of subclass, subclass.from_id(2)
        assert_raises(NoMethodError) { @base.new(1) }
      end

      def test_the_class_that_extends_it_still_hears_of_its_descendants
        heard = []
        parent = Class.new { define_singleton_method(:inherited) { |subclass| heard << subclass } }
        base = Class.new(parent) do
          extend Resources.const_get(:AbstractClass)

          def self.from_id = nil
          def self.from_response = nil
          private_class_method :new, :from_id, :from_response
        end
        subclass = Class.new(base)

        assert_equal [base, subclass], heard
      end

      def test_a_class_that_descends_from_a_descendant_builds
        assert_equal 3, Class.new(Class.new(@base)).from_id(3).id
      end
    end
  end
end
