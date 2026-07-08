class CreateReports < ActiveRecord::Migration[8.0]
  def change
    create_table :reports do |t|
      t.string :name
      t.string :report_type
      t.text :filters
      t.text :report_data
      t.boolean :status
      t.datetime :generated_at
      t.integer :created_by_id

      t.timestamps
    end
  end
end
