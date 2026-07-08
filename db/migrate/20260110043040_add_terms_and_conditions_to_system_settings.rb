class AddTermsAndConditionsToSystemSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :system_settings, :terms_and_conditions, :text
  end
end
