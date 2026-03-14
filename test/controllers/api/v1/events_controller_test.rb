require "test_helper"

class Api::V1::EventsControllerTest < ActionDispatch::IntegrationTest
  test "create successful event" do
    assert_enqueued_jobs 1 do
      post api_v1_sink_events_url(token: sinks(:telebugs).token),
        params: {
          event: "checkout.opened",
          text: "New checkout session opened",
          emoji: "🛒",
          properties: { user_id: 123, plan: "premium" }
        },
        as: :json
    end

    assert_response :created
  end

  test "create with minimal required data" do
    assert_enqueued_jobs 1 do
      post api_v1_sink_events_url(token: sinks(:telebugs).token),
        params: { event: "test.event.happened", text: "Something happened" },
        as: :json
    end

    assert_response :created
  end

  test "returns 422 with error message when text is missing" do
    assert_no_enqueued_jobs do
      post api_v1_sink_events_url(token: sinks(:telebugs).token),
        params: { event: "test.event" },
        as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "Text can't be blank" ], response.parsed_body["errors"]
  end

  test "create requires valid sink token" do
    post api_v1_sink_events_url(token: "invalid-token"),
      params: { event: "test", text: "hi" },
      as: :json

    assert_response :unauthorized
  end
end
