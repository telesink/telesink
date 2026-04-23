class SinksController < ApplicationController
  layout "news", only: %i[new]

  skip_demo_restrictions only: %i[index show]
  before_action :ensure_can_administer, only: %i[new create edit update destroy]
  before_action :set_sink_memberships, only: %i[index show new edit create update destroy]
  before_action :set_sink, only: %i[show edit update destroy]

  def index
    if turbo_frame_request? && turbo_frame_request_id == "sinks"
      render turbo_stream: turbo_stream.update(:sinks, partial: "sinks/sinks")
      return
    end

    sink_to_redirect = if Current.user.current_sink_id.present?
      @sink_memberships.find { |m| m.sink_id == Current.user.current_sink_id }&.sink
    end
    sink_to_redirect ||= @sink_memberships.first&.sink

    if sink_to_redirect
      redirect_to sink_to_redirect, status: :see_other
    end
  end

  def show
    if turbo_frame_request? && turbo_frame_request_id == "sinks"
      render turbo_stream: turbo_stream.update(:sinks, partial: "sinks/sinks")
      return
    end

    membership = @sink.sink_memberships.find_by(user: Current.user)
    @membership = membership

    if membership
      @seen_cutoffs = {}

      if membership.column_last_viewed_at.present?
        membership.column_last_viewed_at.each do |col_id, ts|
          @seen_cutoffs[col_id.to_i] = Time.zone.parse(ts) if ts.present?
        end
      end

      membership.update!(has_unread_events: false)
      membership.mark_all_columns_viewed
    end

    if Current.user.current_sink_id != @sink.id
      Current.user.update!(current_sink_id: @sink.id)
    end
  end

  def new
    @sink = Sink.new
  end

  def create
    @sink = Current.account.sinks.new(sink_params)

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
        .includes(sink: :folder)
        .order("folders.name ASC NULLS LAST, sinks.name ASC")
  end

  def set_sink
    @sink = Current.user.sinks.find(params[:id])
  end

  def sink_params
    params.require(:sink).permit(:name, :folder_id)
  end
end
