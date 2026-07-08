class CreateAgencyCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :agency_codes do |t|
      t.string :insurance_type
      t.string :company_name
      t.string :agent_name
      t.string :code

      t.timestamps
    end
  end
end
