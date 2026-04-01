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
end
