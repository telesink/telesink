class Sink < ApplicationRecord
  has_secure_token :token

  belongs_to :account
  belongs_to :folder, optional: true

  has_many :events, dependent: :destroy

  has_many :sink_memberships, dependent: :destroy
  has_many :users, through: :sink_memberships

  has_many :columns, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true
end
