module SinksHelper
  def sink_title(sink)
    return sink.name unless sink.folder

    "#{sink.folder.name} / #{sink.name}"
  end

  def grouped_sink_memberships(memberships)
    memberships_by_folder = memberships.to_a.group_by { |membership| membership.sink.folder }

    {
      folders: memberships_by_folder
        .reject { |folder, _folder_memberships| folder.nil? }
        .sort_by { |folder, _folder_memberships| folder.name.downcase },
      unfiled: memberships_by_folder[nil].to_a.sort_by { |membership| membership.sink.name.downcase }
    }
  end
end
