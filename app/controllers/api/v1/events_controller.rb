class Api::V1::EventsController < Api::V1::BaseController
  include Telesink::Authentication

  def create
    ProcessEventJob.perform_later(@sink, event_params)

    head :created
  end

  private

  def event_params
    params[:event].permit(:event_type, :emoji, :text, payload: {})
  end
end
