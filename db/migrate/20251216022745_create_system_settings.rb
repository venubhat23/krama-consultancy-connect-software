class CreateSystemSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :system_settings do |t|
      t.string :key, null: false
      t.text :value
      t.text :description
      t.string :setting_type

      t.timestamps
    end

    add_index :system_settings, :key, unique: true

    # Insert default company expenses percentage setting
    SystemSetting.create!(
      key: 'company_expenses_percentage',
      value: '2.0',
      description: 'Company expenses percentage that can be configured by admin',
      setting_type: 'percentage'
    )
  end
end
