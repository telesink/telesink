class Sinks::EventsController < ApplicationController
  skip_demo_restrictions only: %i[index]

  before_action :set_sink
  before_action :set_event_type
  before_action :set_event_date
  before_action :set_property_filter

  def index
    @events = Event.feed_batch(
      @sink,
      before_id: params[:before_id],
      event_type: @event_type,
      date: @event_date,
      property_key: @property_key,
      property_op: @property_op,
      property_value: @property_value
    )

    render formats: [ :turbo_stream ]
  end

  private

  def set_sink
    @sink = Current.user.sinks.find(params[:sink_id])
  end

  def set_event_type
    @event_type = params[:event_type].to_s.strip.presence
  end

  def set_event_date
    return if params[:date].blank?

    @event_date = Date.iso8601(params[:date])
  rescue Date::Error
    @event_date = nil
  end

  def set_property_filter
    @property_key = params[:property_key].to_s.strip.presence
    @property_op = params[:property_op].to_s.strip.presence || "eq"
    @property_value = params[:property_value].to_s if @property_key && params.key?(:property_value)

    unless @property_key && Event::PROPERTY_FILTER_OPS.include?(@property_op)
      @property_key = nil
      @property_op = nil
      @property_value = nil
      return
    end

    if @property_op == "eq" && @property_value.nil?
      @property_key = nil
      @property_op = nil
    elsif Event.numeric_property_filter_op?(@property_op)
      @property_value = Event.property_numeric_filter_value(@property_value)

      if @property_value.nil?
        @property_key = nil
        @property_op = nil
      end
    elsif @property_op == "exists"
      @property_value = nil
    end
  end
end
