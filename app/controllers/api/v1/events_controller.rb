class Api::V1::EventsController < Api::V1::BaseController
  include Telesink::Authentication

  def create
    event = Telesink::Event.new(event_params)

    if event.valid?
      ProcessEventJob.perform_later(@sink, event_params)
      head :created
    else
      render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def event_params
    params.permit(
      :event, :emoji, :text, :occurred_at, :idempotency_key, :token,
      properties: {},
      sdk: [ :name, :version ]
    )
  end
end
