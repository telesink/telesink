class Folder < ApplicationRecord
  belongs_to :account

  has_many :sinks, -> { order(:name) }, dependent: :nullify

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
