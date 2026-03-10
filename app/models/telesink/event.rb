class Telesink::Event
  def initialize(payload)
    @raw = payload
  end

  def event_type
    @raw[:event_type] || "message"
  end

  def emoji
    @raw[:emoji].presence || "📌"
  end

  def text
    @raw[:text].presence || @raw[:message]
  end

  def payload
    @raw[:payload].presence || @raw.except(:event_type, :emoji, :text, :message, :occurred_at, :token, :controller, :action)
  end

  def occurred_at
    if @raw[:occurred_at].present?
      @raw[:occurred_at].is_a?(String) ? Time.parse(@raw[:occurred_at]) : @raw[:occurred_at]
    else
      Time.current
    end
  end
end
