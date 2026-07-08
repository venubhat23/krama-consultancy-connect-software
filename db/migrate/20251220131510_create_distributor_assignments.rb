class CreateDistributorAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :distributor_assignments do |t|
      t.references :distributor, null: false, foreign_key: true
      t.references :sub_agent, null: false, foreign_key: true
      t.datetime :assigned_at

      t.timestamps
    end
  end
end
