class SinksController < ApplicationController
  layout :set_layout
  helper NavigationHelper

  skip_demo_restrictions only: %i[index show]
  before_action :ensure_can_administer, only: %i[new create edit update destroy]
  before_action :set_sink_memberships, only: %i[index show new edit create update destroy]
  before_action :set_folders, only: %i[new edit create update]
  before_action :set_sink, only: %i[show edit update destroy]
  before_action :set_current_context, only: %i[show edit]

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

    @membership = @sink.sink_memberships.find_by(user: Current.user)
    @seen_cutoff = @membership&.last_viewed_at
    set_feed_filters
    @feed_can_mark_viewed = Event.feed_can_mark_viewed?(params)
    @membership&.mark_sink_viewed! if @feed_can_mark_viewed
    @events = Event.feed_batch(
      @sink,
      event_type: @event_type,
      date: @event_date,
      property_key: @property_key,
      property_op: @property_op,
      property_value: @property_value,
      search_query: @search_query,
      time_zone: browser_time_zone
    )
    set_event_type_counts
    set_event_type_icons
    @saved_views = @sink.saved_views.where(user: Current.user).ordered
    set_event_calendar
  end

  def new
    @sink = Sink.new
  end

  def create
    @sink = Current.account.sinks.new(sink_params)

    if @sink.save
      @sink.users << Current.user unless @sink.users.include?(Current.user)
      set_current_context
      set_sink_memberships
      @membership = @sink.sink_memberships.find_by(user: Current.user)
      @membership&.mark_sink_viewed!
      @event_type = nil
      @event_date = nil
      @property_key = nil
      @property_op = nil
      @property_value = nil
      @search_query = nil
      @feed_can_mark_viewed = true
      @events = Event.feed_batch(@sink)
      set_event_type_counts
      set_event_type_icons
      @saved_views = @sink.saved_views.none
      set_event_calendar

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
      render :new, layout: "news", status: :unprocessable_entity
    end
  end

  def edit
    @event_types = @sink.events.distinct.pluck(:event_type).sort
  end

  def update
    if @sink.update(sink_params)
      redirect_to @sink
    else
      render :edit, layout: "editable_sinks", status: :unprocessable_entity
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
        .joins(:sink)
        .includes(sink: :folder)
        .order("sinks.name ASC")
  end

  def set_sink
    @sink = Current.user.sinks.find(params[:id])
  end

  def sink_params
    attributes = params.require(:sink).permit(:name, :folder_id)
    attributes[:folder_id] = nil if attributes[:folder_id].blank?

    if attributes[:folder_id].present? && !Current.account.folders.exists?(attributes[:folder_id])
      attributes.delete(:folder_id)
    end

    attributes
  end

  def set_folders
    @folders = Current.account.folders.ordered
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
    Current.sink = @sink
    Current.folder = nil

    Current.user.update_columns(
      current_sink_id: @sink.id,
      current_folder_id: nil
    )
  end

  def set_feed_filters
    filters = Event.normalize_feed_filters(params)

    @event_type = filters[:event_type]
    @event_date = filters[:event_date]
    @search_query = filters[:search_query]
    @property_key = filters[:property_key]
    @property_op = filters[:property_op]
    @property_value = filters[:property_value]
  end

  def set_event_type_counts
    @event_type_counts = Event
      .feed_scope(
        @sink,
        date: @event_date,
        property_key: @property_key,
        property_op: @property_op,
        property_value: @property_value,
        search_query: @search_query,
        time_zone: browser_time_zone
      )
      .group(:event_type)
      .order(:event_type)
      .count

    @event_type_counts_can_stream = event_type_counts_can_stream?
  end

  def set_event_type_icons
    event_types = @event_type_counts.keys.compact
    @event_type_icons = {}
    return if event_types.empty?

    Event
      .where(sink: @sink, event_type: event_types)
      .where.not(emoji: [ nil, "" ])
      .order(id: :desc)
      .pluck(:event_type, :emoji)
      .each do |event_type, emoji|
        @event_type_icons[event_type] ||= emoji
      end
  end

  def event_type_counts_can_stream?
    Event.normalize_event_date(params[:month]).blank? &&
      @event_date.blank? &&
      @search_query.blank? &&
      @property_key.blank?
  end

  def set_event_calendar
    calendar_month = Event.normalize_event_date(params[:month])
    @calendar_month = (
      calendar_month ||
      @event_date ||
      newest_event_date_for_calendar ||
      browser_time_zone.today
    ).beginning_of_month
    month_range = Event.month_range_for(@calendar_month, time_zone: browser_time_zone)
    local_date_sql = Event.local_date_sql(time_zone: browser_time_zone)

    @event_dates = Event
      .feed_scope(
        @sink,
        event_type: @event_type,
        property_key: @property_key,
        property_op: @property_op,
        property_value: @property_value,
        search_query: @search_query,
        time_zone: browser_time_zone
      )
      .where(occurred_at: month_range)
      .group(Arel.sql(local_date_sql))
      .count
      .transform_keys { |date| Date.parse(date.to_s) }
  end

  def newest_event_date_for_calendar
    Event
      .feed_scope(
        @sink,
        event_type: @event_type,
        property_key: @property_key,
        property_op: @property_op,
        property_value: @property_value,
        search_query: @search_query,
        time_zone: browser_time_zone
      )
      .maximum(:occurred_at)
      &.in_time_zone(browser_time_zone)
      &.to_date
  end
end
