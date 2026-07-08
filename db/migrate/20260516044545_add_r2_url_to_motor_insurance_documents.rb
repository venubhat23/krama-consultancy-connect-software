class AddR2UrlToMotorInsuranceDocuments < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:motor_insurance_documents)
    add_column :motor_insurance_documents, :r2_url, :string unless column_exists?(:motor_insurance_documents, :r2_url)
  end
end
