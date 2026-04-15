module Authorization
  private

  def ensure_can_administer
    head :forbidden unless Current.user.admin? || Current.user.owner?
  end
end
