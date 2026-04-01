module DemoRestrictions
  extend ActiveSupport::Concern

  included do
    before_action :enforce_demo_restrictions, if: -> { Rails.env.demo? }
  end

  class_methods do
    def skip_demo_restrictions(**options)
      skip_before_action :enforce_demo_restrictions, **options
    end
  end

  private

  def enforce_demo_restrictions
    redirect_back fallback_location: root_path
  end
end
