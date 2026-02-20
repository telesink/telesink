class Sink < ApplicationRecord
  has_many :sink_memberships, dependent: :destroy
  has_many :users, through: :sink_memberships
end
