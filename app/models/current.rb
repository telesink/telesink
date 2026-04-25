class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true

  delegate :account, to: :user

  attribute :sink
  attribute :folder

  def sink
    super || (user&.current_sink_id ? Sink.find_by(id: user.current_sink_id) : nil)
  end

  def folder
    super || (user&.current_folder_id ? Folder.find_by(id: user.current_folder_id) : nil)
  end
end
