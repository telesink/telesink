class SinkMembership < ApplicationRecord
  VIEWING_TTL = 45.seconds

  belongs_to :user
  belongs_to :sink

  def actively_viewing_sink?
    user.currently_viewing?(sink) &&
      last_viewed_at.present? &&
      last_viewed_at > VIEWING_TTL.ago
  end

  def mark_sink_viewed!
    update!(
      has_unread_events: false,
      unread_count: 0,
      last_viewed_at: Time.current
    )

    broadcast_sink_list_item! if saved_change_to_has_unread_events? || saved_change_to_unread_count?
  end

  def increment_unread!
    with_lock do
      update!(
        has_unread_events: true,
        unread_count: unread_count + 1
      )
    end

    broadcast_sink_list_item!
  end

  def last_viewed_at_for(column)
    return unless column_last_viewed_at[column.id.to_s]

    Time.zone.parse(column_last_viewed_at[column.id.to_s]) rescue nil
  end

  def mark_all_columns_viewed
    sink.columns.each do |column|
      self.column_last_viewed_at[column.id.to_s] = Time.current.iso8601
    end

    save!
  end

  private

  def broadcast_sink_list_item!
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user_id}_sinks",
      target: ActionView::RecordIdentifier.dom_id(sink, "list_item"),
      partial: "sinks/sink",
      locals: {
        current_sink_id: user.current_sink_id,
        sink: sink,
        membership: self,
        can_administer: user.can_administer?,
        in_folder: sink.folder_id.present?
      }
    )
  end
end
