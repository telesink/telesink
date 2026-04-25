class User < ApplicationRecord
  include Role, Transferable

  belongs_to :account

  has_secure_password
  has_many :sessions, dependent: :destroy

  has_many :sink_memberships, dependent: :destroy
  has_many :sinks, -> { order(created_at: :asc) }, through: :sink_memberships

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :nickname, presence: true

  after_initialize :ensure_nickname
  before_validation :ensure_nickname, on: :create

  def self.role_options
    roles.keys.map { |r| [ r, r ] }
  end

  def can_administer?
    admin? || owner?
  end

  def currently_viewing?(resource)
    return false unless resource

    if resource.is_a?(Sink)
      current_sink_id == resource.id
    elsif resource.is_a?(Folder)
      current_folder_id == resource.id
    else
      false
    end
  end

  private

  def ensure_nickname
    return if email_address.blank?

    self.nickname ||= email_address.to_s.split("@").first
  end
end
