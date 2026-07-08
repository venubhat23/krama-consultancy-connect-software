class AddGstFieldsToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :first_year_gst_percentage, :decimal unless column_exists?(:life_insurances, :first_year_gst_percentage)
    add_column :life_insurances, :second_year_gst_percentage, :decimal unless column_exists?(:life_insurances, :second_year_gst_percentage)
    add_column :life_insurances, :third_year_gst_percentage, :decimal unless column_exists?(:life_insurances, :third_year_gst_percentage)
  end
end
