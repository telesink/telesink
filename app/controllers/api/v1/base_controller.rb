class Api::V1::BaseController < ActionController::Base
  skip_before_action :verify_authenticity_token
end
