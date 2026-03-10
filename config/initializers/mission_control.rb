Rails.application.configure do
  MissionControl::Jobs.http_basic_auth_user = ENV["MISSION_CONTROL_USER"]
  MissionControl::Jobs.http_basic_auth_password = ENV["MISSION_CONTROL_PASSWORD"]
end
