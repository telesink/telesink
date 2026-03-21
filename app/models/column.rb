class Column < ApplicationRecord
  belongs_to :sink

  validates :name, presence: true

  def recent_events(limit: 30)
    sink.events.for_column(self).limit(limit)
  end

  def filters
    (config || {})["filters"] || {}
  end

  def event_types
    Array(filters["event_types"])
  end

  def search_term
    filters["search"].to_s.strip.presence
  end

  def matches_event?(event)
    return false unless event.sink_id == sink_id

    if event_types.any? && !event_types.include?(event.event_type)
      return false
    end

    if search_term.present?
      return false unless event.text.to_s.downcase.include?(search_term.downcase)
    end

    true
  end
end
