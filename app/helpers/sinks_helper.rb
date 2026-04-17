module SinksHelper
  def sink_title(sink)
    [ sink.folder&.name, sink.name ].compact.join("/")
  end
end
