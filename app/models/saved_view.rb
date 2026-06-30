class SavedView < ApplicationRecord
  belongs_to :sink
  belongs_to :user

  validates :name, presence: true, length: { maximum: 80 }
  validates :event_type, length: { maximum: 255 }, allow_nil: true
  validates :search_query, length: { maximum: 255 }, allow_nil: true
  validates :property_key, length: { maximum: 255 }, allow_nil: true
  validates :property_op,
            inclusion: { in: Event::PROPERTY_FILTER_OPS },
            allow_nil: true
  validates :property_value, length: { maximum: 1024 }, allow_nil: true
  validates :name, uniqueness: { scope: %i[user_id sink_id] }
  validate :has_at_least_one_filter

  before_validation :normalize_fields
  before_validation :assign_default_name, on: :create
  before_validation :assign_unique_name, on: :create

  scope :ordered, -> { order(:name, :id) }

  def self.property_filter_label(property_key, property_op, property_value)
    return unless property_key.present?

    if property_op == "exists"
      "#{property_key} exists"
    elsif property_op == "lt" && !property_value.nil?
      "#{property_key} < #{property_value}"
    elsif property_op == "gt" && !property_value.nil?
      "#{property_key} > #{property_value}"
    elsif !property_value.nil?
      "#{property_key}=#{property_filter_value_label(property_value)}"
    end
  end

  def self.property_filter_value_label(property_value)
    value = Event.normalize_utf8_string(property_value)

    value.blank? ? value.inspect : value
  end

  def self.filter_parts(
    event_type:,
    event_date:,
    property_key:,
    property_op:,
    property_value:,
    search_query:,
    today_label: false,
    time_zone: Time.zone
  )
    filters = Event.normalize_feed_filters(
      event_type: event_type,
      event_date: event_date,
      property_key: property_key,
      property_op: property_op,
      property_value: property_value,
      search_query: search_query
    )

    parts = []
    parts << Event.event_type_label(filters[:event_type]) if filters[:event_type].present?

    if filters[:event_date].present?
      parts << if today_label && filters[:event_date] == Event.resolve_time_zone(time_zone).today
        "today"
      else
        filters[:event_date].iso8601
      end
    end

    if filters[:search_query].present?
      parts << %("#{filters[:search_query].truncate(48, omission: "…")}")
    end

    property_label = property_filter_label(
      filters[:property_key],
      filters[:property_op],
      filters[:property_value]
    )
    parts << property_label if property_label.present?

    parts
  end

  def filter_params
    Event.feed_filter_params(self)
  end

  def matches_filters?(
    event_type:,
    event_date:,
    property_key:,
    property_op:,
    property_value:,
    search_query:
  )
    filters = Event.normalize_feed_filters(
      event_type: event_type,
      event_date: event_date,
      property_key: property_key,
      property_op: property_op,
      property_value: property_value,
      search_query: search_query
    )

    self.event_type == filters[:event_type] &&
      self.event_date == filters[:event_date] &&
      self.property_key == filters[:property_key] &&
      self.property_op == filters[:property_op] &&
      self.property_value == filters[:property_value] &&
      self.search_query == filters[:search_query]
  end

  def filter_summary
    self.class
      .filter_parts(
        event_type: event_type,
        event_date: event_date,
        property_key: property_key,
        property_op: property_op,
        property_value: property_value,
        search_query: search_query
      )
      .join(" ")
  end

  private

  def normalize_fields
    self.name = truncate_name(Event.normalize_utf8_string(name).strip)

    filters = Event.normalize_feed_filters(self)

    self.event_type = filters[:event_type]
    self.event_date = filters[:event_date]
    self.search_query = filters[:search_query]
    self.property_key = filters[:property_key]
    self.property_op = filters[:property_op]
    self.property_value = filters[:property_value]
  end

  def has_at_least_one_filter
    return if event_type.present? || event_date.present? || property_key.present? || search_query.present?

    errors.add(:base, "choose at least one filter")
  end

  def assign_default_name
    self.name = truncate_name(default_name) if name.blank?
  end

  def assign_unique_name
    return if name.blank? || sink_id.blank? || user_id.blank?
    return unless self.class.exists?(sink_id: sink_id, user_id: user_id, name: name)

    base_name = truncate_name(name)
    suffix = 2

    loop do
      candidate = suffixed_name(base_name, suffix)

      unless self.class.exists?(sink_id: sink_id, user_id: user_id, name: candidate)
        self.name = candidate
        break
      end

      suffix += 1
    end
  end

  def default_name
    filter_summary.presence || "view"
  end

  def suffixed_name(base_name, suffix)
    suffix_text = " #{suffix}"
    truncate_name(base_name, 80 - suffix_text.length) + suffix_text
  end

  def truncate_name(value, length = 80)
    Event.normalize_utf8_string(value).truncate(length, omission: "")
  end
end
