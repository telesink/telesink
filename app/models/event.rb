class Event < ApplicationRecord
  belongs_to :sink

  validates :event_type, presence: true
  validates :text, presence: true

  validates :idempotency_key,
            uniqueness: { scope: :sink_id },
            allow_nil: true,
            length: { maximum: 255 }

  scope :for_column, ->(column) {
    rel = where(sink_id: column.sink_id)

    if column.event_types.any?
      rel = rel.where(event_type: column.event_types)
    end

    if (term = column.search_term)
      rel = rel.where("text ILIKE ?", "%#{term}%")

      # Optional later: also search inside properties
      # rel = rel.or(where("properties::text ILIKE ?", "%#{term}%"))
    end

    rel.order(occurred_at: :desc, id: :desc)
  }

  after_create_commit :broadcast_to_matching_columns

  private

  def broadcast_to_matching_columns
    sink.columns.each do |column|
      next unless column.matches_event?(self)

      if column.has_events?
        Turbo::StreamsChannel.broadcast_prepend_to(
          sink,
          target: "events_list_#{column.id}",
          partial: "events/preview_card",
          locals: { event: self, column: column, new_event: true }
        )

      else
        column.update_column(:has_events, true)

        Turbo::StreamsChannel.broadcast_replace_to(
          sink,
          target: column,
          partial: "sinks/columns/column",
          locals: { event: self, column: column, new_event: true }
        )
      end
    end
  end
end
