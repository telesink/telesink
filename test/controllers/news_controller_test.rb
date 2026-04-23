require "test_helper"

class NewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:kyrylo)
  end

  test "show redirects to new sink page" do
    get new_path
    assert_redirected_to new_sink_path
  end
end
