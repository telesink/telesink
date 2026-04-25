class Sinks::EventTypesController < ApplicationController
  include SinkScoped

  before_action :ensure_can_administer
  before_action :set_sink_memberships, only: %i[index show]
  before_action :set_event_type, only: %i[show destroy]

  def index
    @event_types = @sink.events.distinct.pluck(:event_type).sort

    render partial: "sinks/event_types/index", locals: { sink: @sink }
  end

  def show
    @event_types = @sink.events.distinct.pluck(:event_type).sort
    @count = @sink.events.where(event_type: @event_type).count
  end

  def destroy
    @event_types = @sink.events.distinct.pluck(:event_type).sort

    @sink.events.where(event_type: @event_type).delete_all

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "event_types",
            partial: "sinks/event_types/index",
            locals: { sink: @sink }
          )
        ]
      end
      format.html { redirect_to edit_sink_path(@sink) }
    end
  end

  private

  def set_sink_memberships
    @sink_memberships =
      Current
        .user
        .sink_memberships
        .includes(sink: :folder)
        .order("folders.name ASC NULLS LAST, sinks.name ASC")
  end

  def set_event_type
    @event_type = params[:id]
  end
end
