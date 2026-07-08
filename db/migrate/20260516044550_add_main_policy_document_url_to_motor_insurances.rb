class AddMainPolicyDocumentUrlToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:motor_insurances)
    add_column :motor_insurances, :main_policy_document_url, :string unless column_exists?(:motor_insurances, :main_policy_document_url)
  end
end
