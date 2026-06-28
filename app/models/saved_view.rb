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

  scope :ordered, -> { order(:name, :id) }

  def filter_params
    {
      event_type: event_type,
      date: event_date&.iso8601,
      property_key: property_key,
      property_op: property_op,
      property_value: property_value,
      q: search_query
    }.compact
  end

  def matches_filters?(
    event_type:,
    event_date:,
    property_key:,
    property_op:,
    property_value:,
    search_query:
  )
    self.event_type == event_type &&
      self.event_date == event_date &&
      self.property_key == property_key &&
      self.property_op == property_op &&
      self.property_value == property_value &&
      self.search_query == search_query
  end

  private

  def normalize_fields
    self.name = name.to_s.strip
    self.event_type = event_type.to_s.strip.presence
    self.search_query = Event.normalize_search_query(search_query)
    self.property_key = property_key.to_s.strip.presence
    self.property_op = property_op.to_s.strip.presence || "eq"
    self.property_value = property_value.to_s if property_key && !property_value.nil?

    unless property_key && Event::PROPERTY_FILTER_OPS.include?(property_op)
      self.property_key = nil
      self.property_op = nil
      self.property_value = nil
      return
    end

    if property_op == "eq" && property_value.nil?
      self.property_key = nil
      self.property_op = nil
    elsif Event.numeric_property_filter_op?(property_op)
      self.property_value = Event.property_numeric_filter_value(property_value)

      if property_value.nil?
        self.property_key = nil
        self.property_op = nil
      end
    elsif property_op == "exists"
      self.property_value = nil
    end
  end

  def has_at_least_one_filter
    return if event_type.present? || event_date.present? || property_key.present? || search_query.present?

    errors.add(:base, "choose at least one filter")
  end
end
