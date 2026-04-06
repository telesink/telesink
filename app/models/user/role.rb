module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, %i[ member admin owner ], default: :member
  end
end
