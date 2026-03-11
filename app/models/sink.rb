class Sink < ApplicationRecord
  has_secure_token :token

  has_many :events, dependent: :destroy

  has_many :sink_memberships, dependent: :destroy
  has_many :users, through: :sink_memberships

  has_many :columns, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true

  before_validation :build_default_column, on: :create

  private

  def build_default_column
    return if columns.any?

    columns.build(name: "all events")
  end
end
