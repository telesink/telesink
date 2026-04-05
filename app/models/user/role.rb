module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, %i[ member admin ], default: :member
  end
end
