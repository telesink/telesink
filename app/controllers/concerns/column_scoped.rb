module ColumnScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_column
  end

  private

  def set_column
    @sink = Column.find(params[:column_id])
  end
end
