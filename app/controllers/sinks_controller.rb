class SinksController < ApplicationController
  before_action :set_sinks, only: %i[index show new edit create update destroy]
  before_action :set_sink, only: %i[show edit update destroy]

  def index
    if turbo_frame_request? && turbo_frame_request_id == "sinks"
      render partial: "sinks", layout: false
      return
    end

    if (first_sink = @sinks.first)
      redirect_to first_sink, status: :see_other
    end
  end

  def show
  end

  def new
    @sink = Sink.new

    @back_path = request.referer.presence
    @back_path ||= (@sinks.first ? sink_path(@sinks.first) : root_path)
  end

  def create
    @sink = Sink.new(sink_params)

    if @sink.save
      @sink.users << Current.user unless @sink.users.include?(Current.user)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update(:sinks, partial: "sinks"),
            turbo_stream.update(:main_content, template: "sinks/show")
          ]
        end
        format.html { redirect_to @sink }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @back_path = sink_path(@sink)
  end

  def update
    if @sink.update(sink_params)
      redirect_to @sink
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @sink.destroy

    if (remaining_sink = @sinks.first)
      redirect_to remaining_sink, status: :see_other
    else
      redirect_to sinks_path
    end
  end

  private

  def set_sinks
    @sinks = Current.user.sinks.order(created_at: :asc)
  end

  def set_sink
    @sink = Current.user.sinks.find(params[:id])
  end

  def sink_params
    params.require(:sink).permit(:name)
  end
end
