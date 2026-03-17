class Telesink::Event
  include ActiveModel::Validations

  validates :text, presence: true

  def initialize(raw)
    @event = raw[:event]
    @emoji = raw[:emoji]
    @text = raw[:text]
    @properties = (raw[:properties] || {}).dup.freeze
    @occurred_at_raw = raw[:occurred_at]
    @idempotency_key = raw[:idempotency_key]

    sdk = raw[:sdk] || {}
    @sdk_name = sdk[:name]
    @sdk_version = sdk[:version]
  end

  def event_type
    @event.presence || "event"
  end

  def emoji
    @emoji.presence || "📌"
  end

  def text
    @text.presence
  end

  def properties
    @properties
  end

  def occurred_at
    @occurred_at ||= begin
      return if @occurred_at_raw.blank?

      Time.parse(@occurred_at_raw.to_s).utc
    rescue ArgumentError, TypeError
      nil
    end
  end

  def idempotency_key
    @idempotency_key.presence
  end

  def sdk_name
    @sdk_name
  end

  def sdk_version
    @sdk_version
  end
end
