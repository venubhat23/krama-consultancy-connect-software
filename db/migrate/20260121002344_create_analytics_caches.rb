class CreateAnalyticsCaches < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_caches do |t|
      t.string :cache_identifier
      t.text :cache_data
      t.datetime :last_updated

      t.timestamps
    end
    add_index :analytics_caches, :cache_identifier, unique: true
  end
end
