# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A value of a response that cannot be read as what the API documents it to be raises InvalidAttribute, an
  # X::Error, where it is read, and the same value passed by a caller raises ArgumentError
  class InvalidAttributeTest < Minitest::Test
    cover Objects::Attributes
    cover Objects::Utils
    cover Resource
    cover Usage

    def test_an_invalid_attribute_is_an_error_of_the_object_layer
      assert_operator InvalidAttribute, :<, Objects::Error
    end

    def test_a_timestamp_that_is_not_iso_8601_raises_where_it_is_read
      post = Post.new({"id" => "1", "created_at" => "yesterday"})
      error = assert_raises(InvalidAttribute) { post.created_at }

      assert_equal "X::Post#created_at cannot be read from \"yesterday\"", error.message
      assert_instance_of ArgumentError, error.cause
    end

    def test_an_attribute_names_its_class_and_reader_when_it_cannot_be_read
      klass = Class.new(Resource) { attribute :stamped_at, :time }
      error = assert_raises(InvalidAttribute) { klass.new({"id" => "1", "stamped_at" => "soon"}).stamped_at }

      assert_equal "#{klass}#stamped_at cannot be read from \"soon\"", error.message
    end

    def test_an_identifier_that_is_not_a_number_raises_where_it_is_read
      error = assert_raises(InvalidAttribute) { Post.new({"id" => "1", "conversation_id" => "12a"}).conversation_id }

      assert_equal "X::Post#conversation_id cannot be read from \"12a\"", error.message
    end

    def test_a_list_of_identifiers_that_holds_one_that_is_not_a_number_raises_where_it_is_read
      assert_raises(InvalidAttribute) { Space.new({"id" => "a", "host_ids" => %w[1 2b]}).host_ids }
    end

    def test_a_pattern_that_reads_an_invalid_attribute_raises_an_error_of_the_api
      post = Post.new({"id" => "1", "created_at" => "yesterday"})

      assert_raises(X::Error) do
        case post
        in {created_at: Time} then nil
        end
      end
    end

    def test_a_reference_to_an_identifier_that_is_not_one_raises_where_it_is_read
      error = assert_raises(InvalidAttribute) { Post.new({"id" => "1", "author_id" => "12a"}).author }

      assert_equal "The reference of X::Post to X::User cannot be read from \"12a\"", error.message
    end

    def test_a_response_that_holds_a_resource_without_an_identifier_raises
      error = assert_raises(InvalidAttribute) { User.from_response({"data" => [{"id" => "1"}, {"name" => "No one"}]}, client: nil) }

      assert_equal "X::User#id cannot be read from nil", error.message
    end

    def test_a_response_that_holds_a_resource_with_an_identifier_that_is_not_one_raises
      error = assert_raises(InvalidAttribute) { User.resource_from_response({"data" => {"id" => "abc"}}, client: nil) }

      assert_equal "X::User#id cannot be read from \"abc\"", error.message
    end

    def test_a_response_whose_data_is_not_an_object_raises
      assert_raises(InvalidAttribute) { User.collection_from_response({"data" => ["1"]}, client: nil) }
    end

    def test_an_identifier_a_caller_passes_still_raises_argument_error
      assert_raises(ArgumentError) { User.new({"id" => "abc"}) }
      assert_raises(ArgumentError) { User.from_id("abc") }
    end

    def test_the_totals_of_usage_that_cannot_be_read_raise_where_they_are_read
      messages = %w[project_id project_usage project_cap].map do |name|
        assert_raises(InvalidAttribute) { Usage.new({name => "many"}).public_send(name) }.message
      end

      assert_equal %w[project_id project_usage project_cap].map { |name| "X::Usage##{name} cannot be read from \"many\"" }, messages
    end

    def test_the_usage_of_an_app_that_cannot_be_read_raises_where_it_is_read
      usage = Usage.new({"daily_client_app_usage" => [{"client_app_id" => "app", "usage" => []}]})

      assert_equal "X::Usage#daily_by_app cannot be read from \"app\"", assert_raises(InvalidAttribute) { usage.daily_by_app }.message
    end

    def test_a_day_of_usage_that_cannot_be_read_raises_where_it_is_read
      assert_equal "X::Usage#daily cannot be read from \"today\"", daily_error("today", "1").message
      assert_equal "X::Usage#daily cannot be read from \"x\"", daily_error("2026-01-01T00:00:00Z", "x").message
    end

    private

    # The error the daily usage of a day that cannot be read raises
    def daily_error(date, count)
      assert_raises(InvalidAttribute) { Usage.new({"daily_project_usage" => {"usage" => [{"date" => date, "usage" => count}]}}).daily }
    end
  end
end
