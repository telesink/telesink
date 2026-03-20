class Sinks::ColumnsController < ApplicationController
  include SinkScoped

  before_action :set_column, only: %i[edit update show destroy]

  def create
    @column = @sink.columns.build(name: "all events")

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
  end

  def update
    if @column.update(column_params)
      redirect_to @sink
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def show
    @sink = @column.sink
    @events = @sink.events.order(occurred_at: :desc).limit(50)
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
    params.require(:column).permit(:name)
  end
end
