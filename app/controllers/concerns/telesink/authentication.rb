module Telesink::Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
  end

  private

  def require_authentication
    head :unauthorized unless authenticated?
  end

  def authenticated?
    if params[:token].present?
      @sink = Sink.find_by(token: params[:token])
      return @sink.present?
    end

    false
  end
end
