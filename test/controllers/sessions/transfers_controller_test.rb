require "test_helper"

class Sessions::TransfersControllerTest < ActionDispatch::IntegrationTest
  test "signs in the user with a valid transfer link" do
    get session_transfer_url(users(:test_member).transfer_id)

    assert_redirected_to Current.sink || sinks_path
    assert_equal 1, users(:test_member).sessions.where(created_at: 1.minute.ago..).count
  end

  test "rejects an expired or invalid transfer link" do
    get session_transfer_url("invalid-token")

    assert_redirected_to new_session_path
    assert_equal "this sign-in link is invalid or has expired.", flash[:alert]
  end

  test "works even if the user is not currently signed in" do
    delete session_path if respond_to?(:delete)

    get session_transfer_url(users(:test_member).transfer_id)

    assert_redirected_to Current.sink || sinks_path
    assert_equal 1, users(:test_member).sessions.where(created_at: 1.minute.ago..).count
  end
end
