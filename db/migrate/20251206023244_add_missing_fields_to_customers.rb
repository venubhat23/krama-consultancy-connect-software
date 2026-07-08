class AddMissingFieldsToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :nominee_name, :string
    add_column :customers, :nominee_relation, :string
    add_column :customers, :nominee_date_of_birth, :date
    add_column :customers, :pincode, :string
  end
end
