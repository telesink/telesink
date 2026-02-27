class Sink < ApplicationRecord
  has_secure_token :token

  has_many :events, dependent: :destroy

  has_many :sink_memberships, dependent: :destroy
  has_many :users, through: :sink_memberships

  has_many :columns, dependent: :destroy
end
