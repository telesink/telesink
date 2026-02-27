module SinkScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_sink
  end

  private

  def set_sink
    @sink = Sink.find(params[:sink_id])
  end
end
