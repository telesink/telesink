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

  after_create_commit(
    :broadcast_to_matching_columns,
    :mark_unread_for_all_members,
    unless: -> { Rails.env.test? }
  )

  def currently_viewing?(resource)
    return false unless resource

    if resource.is_a?(Sink)
      current_sink_id == resource.id
    elsif resource.is_a?(Folder)
      current_folder_id == resource.id
    else
      false
    end
  end

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

  def mark_unread_for_all_members
    sink.sink_memberships.includes(:user).each do |membership|
      next if membership.has_unread_events?

      currently_viewing =
        membership.user.currently_viewing?(membership.sink) ||
        membership.user.currently_viewing?(membership.sink.folder)

      unless currently_viewing
        membership.update!(has_unread_events: true)
      end

      # Broadcast stays exactly the same
      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{membership.user_id}_sinks",
        target: ActionView::RecordIdentifier.dom_id(membership.sink, "list_item"),
        partial: "sinks/sink",
        locals: {
          current_sink_id: membership.user.current_sink_id,
          sink: membership.sink,
          membership: membership,
          can_administer: membership.user.can_administer?,
          nesting_prefix: membership.nesting_prefix
        }
      )
    end
  end
end
