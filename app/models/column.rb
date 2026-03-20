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
end
