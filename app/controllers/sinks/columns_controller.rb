class Sinks::ColumnsController < ApplicationController
  include SinkScoped

  skip_demo_restrictions # only: %i[show]

  before_action :set_column, only: %i[edit update show destroy]

  def create
    @column = @sink.columns.build(name: "all events")
    @column.has_events = @sink.events.exists?

    if @column.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            "columns-container",
            partial: "sinks/columns/column",
            locals: { column: @column }
          )
        end
        format.html { redirect_to @sink }
      end
    else
      redirect_to @sink, alert: "could not create column."
    end
  end

  def edit
    @available_event_types = @column.sink.events.distinct.pluck(:event_type).sort

    # This route is intended for Turbo Streams, but bots sometimes access it
    # directly, causing 500 errors. This guard prevents the template from making
    # unnecessary queries and failing.
    @sink_memberships = []
  end

  def update
    @column.assign_attributes(column_params.except(:event_types, :search))

    @column.config ||= {}
    @column.config["filters"] = {
      "event_types" => Array(params.dig(:column, :event_types)).reject(&:blank?),
      "search" => params.dig(:column, :search).to_s.strip.presence
    }.compact_blank

    if @column.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            @column,
            partial: "sinks/columns/column",
            locals: { column: @column }
          )
        end
        format.html { redirect_to @sink }
      end
    else
      @available_event_types = @column.sink.events.distinct.pluck(:event_type).sort
      render :edit, status: :unprocessable_entity
    end
  end

  def show
    render turbo_stream: turbo_stream.replace(
      @column,
      partial: "sinks/columns/column",
      locals: { column: @column }
    )
  end

  def destroy
    @column.destroy
    redirect_to @sink, status: :see_other
  end

  private

  def set_column
    @column = @sink.columns.find(params[:column_id] || params[:id])
  end

  def column_params
    params.require(:column).permit(:name, event_types: [], search: nil)
  end
end
