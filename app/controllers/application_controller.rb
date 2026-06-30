class ApplicationController < ActionController::Base
  include Authentication, Authorization, DemoRestrictions

  helper_method :browser_time_zone

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def browser_time_zone
    @browser_time_zone ||= begin
      time_zone_name = cookies[:telesink_time_zone].to_s

      if time_zone_name.length <= 128
        ActiveSupport::TimeZone[time_zone_name] || Time.zone
      else
        Time.zone
      end
    end
  end
end
