class Sinks::ColumnsController < ApplicationController
  include SinkScoped

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
end
