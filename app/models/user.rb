class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  has_many :sink_memberships, dependent: :destroy
  has_many :sinks, -> { order(created_at: :asc) }, through: :sink_memberships

  def nickname
    email_address.split("@").first
  end
end
