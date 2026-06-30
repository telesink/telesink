require "test_helper"

class Sinks::SavedViewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:kyrylo)
    @sink = sinks(:telebugs)
  end

  test "demo environment allows creating saved views" do
    sign_in_as(@user)

    assert_difference "SavedView.count" do
      with_rails_env("demo") do
        post sink_saved_views_path(@sink), params: {
          saved_view: {
            name: "exceptions",
            event_type: "exception"
          }
        }
      end
    end

    assert_redirected_to sink_path(@sink, event_type: "exception")
  end
end
