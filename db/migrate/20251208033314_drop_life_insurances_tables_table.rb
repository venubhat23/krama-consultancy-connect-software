class DropLifeInsurancesTablesTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :life_insurances_tables if table_exists?(:life_insurances_tables)
  end
end
