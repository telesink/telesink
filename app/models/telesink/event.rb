class Telesink::Event
  include ActiveModel::Validations

  validates :text, presence: true

  def initialize(payload)
    @raw = payload.to_h.symbolize_keys
  end

  def event_type
    @raw[:event].presence || "event"
  end

  def emoji
    @raw[:emoji].presence || "📌"
  end

  def text
    @raw[:text].presence
  end

  def properties
    @raw[:properties].presence || {}
  end

  def occurred_at
    @raw[:occurred_at].present? ? Time.parse(@raw[:occurred_at].to_s) : Time.current
  end
end
