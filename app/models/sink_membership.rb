class SinkMembership < ApplicationRecord
  belongs_to :user
  belongs_to :sink

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

  def nesting_prefix
    return "" unless sink.folder_id

    all_memberships = user.sink_memberships
      .includes(sink: :folder)
      .order("folders.name ASC NULLS LAST, sinks.name ASC")
      .to_a

    folder_memberships = all_memberships.select { |m| m.sink.folder_id == sink.folder_id }

    index = folder_memberships.index(self)
    index == folder_memberships.size - 1 ? "└─" : "├─"
  end
end
