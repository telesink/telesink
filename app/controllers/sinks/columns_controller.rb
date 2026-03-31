class Sinks::ColumnsController < ApplicationController
  include SinkScoped

  before_action :set_column, only: %i[edit update show destroy viewed]

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
    @sink = @column.sink
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@column),
          partial: "sinks/columns/column",
          locals: { column: @column }
        )
      end
      format.html { redirect_to @sink }
    end
  end

  def destroy
    @column.destroy
    redirect_to @sink, status: :see_other
  end

  def viewed
    membership = @sink.sink_memberships.find_by(user: Current.user)
    return head :ok unless membership

    membership.column_last_viewed_at ||= {}
    membership.column_last_viewed_at[@column.id.to_s] = Time.current.iso8601
    membership.save!

    head :ok
  end

  private

  def set_column
    @column = @sink.columns.find(params[:column_id] || params[:id])
  end

  def column_params
    params.require(:column).permit(:name, event_types: [], search: nil)
  end
end
