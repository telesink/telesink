module NavigationHelper
  def back_to_current_path
    if Current.folder
      folder_path(Current.folder)
    elsif Current.sink
      sink_path(Current.sink)
    else
      sinks_path
    end
  end

  def folder_has_new_events?(folder, folder_memberships)
    return false unless folder && folder_memberships
    folder_memberships.any? { |m| m.has_unread_events? }
  end
end
