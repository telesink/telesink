module NavigationHelper
  def back_to_current_path
    request.referer.presence ||
      if Current.folder
        folder_path(Current.folder)
      elsif Current.sink
        sink_path(Current.sink)
      else
        sinks_path
      end
  end
end
