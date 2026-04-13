class User < ApplicationRecord
  include Role

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

  private

  def ensure_nickname
    return if email_address.blank?

    self.nickname ||= email_address.to_s.split("@").first
  end
end
