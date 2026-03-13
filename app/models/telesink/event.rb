class Telesink::Event
  EVENT_KEYS = %i[event_type emoji text occurred_at]

  def initialize(payload)
    @raw = payload
  end

  def event_type
    @raw[:event_type] || "event"
  end

  def emoji
    @raw[:emoji].presence || "📌"
  end

  def text
    @raw[:text].presence || ""
  end

  def properties
    @raw[:properties].presence || {}
  end

  def occurred_at
    if @raw[:occurred_at].present?
      Time.parse(@raw[:occurred_at])
    else
      Time.current
    end
  end
end
