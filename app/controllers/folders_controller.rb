class FoldersController < ApplicationController
  layout :set_layout
  helper NavigationHelper

  skip_demo_restrictions only: %i[show]
  before_action :ensure_can_administer, only: %i[new create edit update destroy]
  before_action :set_folder, only: %i[show edit update destroy]
  before_action :set_sink_memberships, only: %i[new edit create update destroy show]
  before_action :set_current_context, only: %i[show edit]

  def show
    @sinks = @folder.sinks
      .order(:name)
      .includes(:columns)

    @sinks.each do |sink|
      membership = sink.sink_memberships.find_by(user: Current.user)
      next unless membership

      membership.update!(has_unread_events: false)
      membership.mark_all_columns_viewed
    end

    @highlight_current_sink = false
  end

  def new
    @folder = Current.account.folders.new
  end

  def create
    @folder = Current.account.folders.new(folder_params)

    if @folder.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(:sinks, partial: "sinks/sinks")
        end
        format.html { redirect_to sinks_path }
      end
    else
      render :new, layout: "news", status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @folder.update(folder_params)
      redirect_to sinks_path
    else
      render :edit, layout: "editable_sinks", status: :unprocessable_entity
    end
  end

  def destroy
    @folder.destroy

    redirect_to sinks_path
  end

  private

  def set_folder
    @folder = Current.account.folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name)
  end

  def set_sink_memberships
    @sink_memberships =
      Current
        .user
        .sink_memberships
        .includes(:sink)
        .order(sinks: { name: :asc })
  end

  def set_layout
    case action_name
    when "new"
      "news"
    when "edit"
      "editable_sinks"
    else
      "application"
    end
  end

  def set_current_context
    Current.folder = @folder
    Current.sink = nil

    Current.user.update_columns(
      current_sink_id: nil,
      current_folder_id: @folder.id
    )
  end
end
