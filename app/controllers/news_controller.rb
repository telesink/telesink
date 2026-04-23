class NewsController < ApplicationController
  layout "new"

  def show
    redirect_to new_sink_path
  end
end
