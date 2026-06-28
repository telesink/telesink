class Sinks::SavedViewsController < ApplicationController
  before_action :set_sink

  def create
    saved_view = @sink.saved_views.new(saved_view_params)
    saved_view.user = Current.user

    if saved_view.save
      redirect_to sink_path(@sink, saved_view.filter_params), status: :see_other
    else
      redirect_to sink_path(@sink, current_filter_params), status: :see_other
    end
  end

  def destroy
    saved_view = @sink.saved_views.where(user: Current.user).find(params[:id])
    saved_view.destroy

    redirect_to sink_path(@sink), status: :see_other
  end

  private

  def set_sink
    @sink = Current.user.sinks.find(params[:sink_id])
  end

  def saved_view_params
    params
      .require(:saved_view)
      .permit(
        :name,
        :event_type,
        :event_date,
        :property_key,
        :property_op,
        :property_value
      )
  end

  def current_filter_params
    saved_view_params
      .slice(:event_type, :event_date, :property_key, :property_op, :property_value)
      .then do |filters|
        filters[:date] = filters.delete(:event_date)
        filters
      end
  end
end
