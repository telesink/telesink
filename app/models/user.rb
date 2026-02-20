class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  has_many :sink_memberships, dependent: :destroy
  has_many :sinks, through: :sink_memberships
end
