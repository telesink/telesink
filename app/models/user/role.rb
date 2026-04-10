module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, %i[ member admin owner ], default: :member

    scope :ordered_by_role, -> {
      order(role: :desc, nickname: :asc)
    }
  end
end
