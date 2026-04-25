module Authorization
  private

  def ensure_can_administer
    return if Current.user.admin?
    return if Current.user.owner?

    head :forbidden
  end
end
