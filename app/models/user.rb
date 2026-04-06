class User < ApplicationRecord
  include Role

  belongs_to :account

  has_secure_password
  has_many :sessions, dependent: :destroy

  has_many :sink_memberships, dependent: :destroy
  has_many :sinks, -> { order(created_at: :asc) }, through: :sink_memberships

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def nickname
    email_address.split("@").first
  end
end
