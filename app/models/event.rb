class Event < ApplicationRecord
  belongs_to :sink

  validates :event_type, presence: true
  validates :text, presence: true

  validates :idempotency_key,
            uniqueness: { scope: :sink_id },
            allow_nil: true,
            length: { maximum: 255 }
end
