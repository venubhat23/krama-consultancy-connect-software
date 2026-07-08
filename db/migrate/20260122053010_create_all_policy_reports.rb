class CreateAllPolicyReports < ActiveRecord::Migration[8.0]
  def change
    create_table :all_policy_reports do |t|
      t.string :name
      t.string :policy_type
      t.json :report_data
      t.integer :created_by_id

      t.timestamps
    end
  end
end
