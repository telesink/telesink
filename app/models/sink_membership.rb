class SinkMembership < ApplicationRecord
  belongs_to :user
  belongs_to :sink
end
