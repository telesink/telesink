class FoldersController < ApplicationController
  layout :set_layout
  helper NavigationHelper

  skip_demo_restrictions only: %i[show]
  before_action :ensure_can_administer, only: %i[new create edit update destroy]
  before_action :set_folder, only: %i[show edit update destroy]
  before_action :set_sink_memberships, only: %i[new edit create update destroy show]

  def show
    sink = @folder.sinks.joins(:sink_memberships)
      .where(sink_memberships: { user_id: Current.user.id })
      .order(:name)
      .first

    redirect_to(sink || sinks_path, status: :see_other)
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
        .includes(sink: :folder)
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

end
