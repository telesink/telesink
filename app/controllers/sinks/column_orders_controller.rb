# app/controllers/sinks/column_orders_controller.rb
class Sinks::ColumnOrdersController < ApplicationController
  include SinkScoped

  skip_demo_restrictions only: %i[update]

  def update
    column_ids = params.require(:column_order)[:column_ids] || []
    column_ids = column_ids.reject(&:blank?).map(&:to_i)

    ActiveRecord::Base.transaction do
      column_ids.each_with_index do |id, index|
        @sink.columns.find(id).update_column(:position, index)
      end
    end

    head :ok
  end
end
