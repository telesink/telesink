class Event < ApplicationRecord
  belongs_to :sink

  validates :event_type, presence: true
  validates :text, presence: true
end
