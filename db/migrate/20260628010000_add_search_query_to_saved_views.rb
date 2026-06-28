class AddSearchQueryToSavedViews < ActiveRecord::Migration[8.1]
  def change
    add_column :saved_views, :search_query, :string
  end
end
