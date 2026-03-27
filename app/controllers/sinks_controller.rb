class SinksController < ApplicationController
  before_action :set_sink_memberships, only: %i[index show new edit create update destroy]
  before_action :set_sink, only: %i[show edit update destroy]

  def index
    if turbo_frame_request? && turbo_frame_request_id == "sinks"
      render partial: "sinks/sinks", layout: false
      return
    end

    if (first_sink = @sink_memberships.first&.sink)
      redirect_to first_sink, status: :see_other
    end
  end

  def show
    if turbo_frame_request? && turbo_frame_request_id == "sinks"
      render partial: "sinks/sinks", layout: false
      return
    end

    membership = @sink.sink_memberships.find_by(user: Current.user)
    membership&.update!(has_unread_events: false)

    if Current.user.current_sink_id != @sink.id
      Current.user.update!(current_sink_id: @sink.id)
    end
  end

  def new
    @sink = Sink.new

    @back_path = request.referer.presence
    @back_path ||= (@sink_memberships.first&.sink ? sink_path(@sink_memberships.first.sink) : root_path)
  end

  def create
    @sink = Sink.new(sink_params)

    if @sink.save
      @sink.users << Current.user unless @sink.users.include?(Current.user)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update(:sinks, partial: "sinks/sinks"),
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

    set_sink_memberships

    if (remaining_sink = @sink_memberships.first&.sink)
      redirect_to remaining_sink, status: :see_other
    else
      redirect_to sinks_path
    end
  end

  private

  def set_sink_memberships
    @sink_memberships =
      Current
        .user
        .sink_memberships
        .includes(:sink)
        .order(sinks: { name: :asc })
  end

  def set_sink
    @sink = Current.user.sinks.find(params[:id])
  end

  def sink_params
    params.require(:sink).permit(:name)
  end
end
