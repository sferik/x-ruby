require_relative "../../test_helper"

module X
  class UserFieldsTest < Minitest::Test
    cover User

    def setup
      @user = User.new({"id" => "1", "profile_banner_url" => "https://pbs.twimg.com/b.jpg", "parody" => true,
                        "is_identity_verified" => true, "subscription_type" => "Premium",
                        "verified_followers_count" => 5, "affiliation" => {"description" => "Anthropic"}})
    end

    def test_the_fields_the_api_added
      assert_equal "https://pbs.twimg.com/b.jpg", @user.profile_banner_url
      assert_equal "Premium", @user.subscription_type
      assert_equal 5, @user.verified_followers_count
      assert_equal({"description" => "Anthropic"}, @user.affiliation)
    end

    def test_parody_and_identity_verified
      assert_predicate @user, :parody?
      assert @user.parody
      assert_predicate @user, :identity_verified?
      assert @user.is_identity_verified
    end

    def test_parody_and_identity_verified_of_a_user_the_api_says_nothing_about
      user = User.new({"id" => "1", "parody" => false, "is_identity_verified" => false})

      assert_instance_of FalseClass, user.parody?
      assert_instance_of FalseClass, user.identity_verified?
      assert_instance_of FalseClass, User.new({"id" => "1"}).parody?
      assert_instance_of FalseClass, User.new({"id" => "1"}).identity_verified?
    end

    def test_the_requested_fields_hold_the_ones_the_api_always_answers
      assert_includes User::FIELDS, "affiliation"
      assert_equal User::FIELDS, User::FIELDS.sort
    end

    def test_the_requested_fields_leave_out_the_ones_that_depend_on_who_is_authenticated
      refute_includes User::FIELDS, "connection_status"
      refute_includes User::FIELDS, "confirmed_email"
      refute_includes User::FIELDS, "receives_your_dm"
      refute_includes User::FIELDS, "subscription"
    end
  end
end
