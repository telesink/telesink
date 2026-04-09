module UsersHelper
  ROLE_SYMBOLS = {
    "owner" => "~",
    "admin" => "@",
    "member" => ""
  }.freeze

  def role_symbol(user)
    ROLE_SYMBOLS.fetch(user.role)
  end
end
