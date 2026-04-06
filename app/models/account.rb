class Account < ApplicationRecord
  include Joinable

  has_many :users, dependent: :destroy
  has_many :sinks, dependent: :destroy
end
