class Column < ApplicationRecord
  belongs_to :sink

  validates :name, presence: true
end
