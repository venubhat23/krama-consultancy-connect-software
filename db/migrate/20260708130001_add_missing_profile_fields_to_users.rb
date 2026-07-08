class AddMissingProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_name, :string unless column_exists?(:users, :first_name)
    add_column :users, :last_name, :string unless column_exists?(:users, :last_name)
    add_column :users, :mobile, :string unless column_exists?(:users, :mobile)
    add_column :users, :gender, :string unless column_exists?(:users, :gender)
    add_column :users, :height, :string unless column_exists?(:users, :height)
    add_column :users, :weight, :string unless column_exists?(:users, :weight)
    add_column :users, :education, :string unless column_exists?(:users, :education)
    add_column :users, :marital_status, :string unless column_exists?(:users, :marital_status)
    add_column :users, :occupation, :string unless column_exists?(:users, :occupation)
    add_column :users, :job_name, :string unless column_exists?(:users, :job_name)
    add_column :users, :type_of_duty, :string unless column_exists?(:users, :type_of_duty)
    add_column :users, :annual_income, :decimal unless column_exists?(:users, :annual_income)
    add_column :users, :birth_place, :string unless column_exists?(:users, :birth_place)
    add_column :users, :state, :string unless column_exists?(:users, :state)
    add_column :users, :city, :string unless column_exists?(:users, :city)
    add_column :users, :status, :boolean unless column_exists?(:users, :status)
    add_column :users, :additional_info, :text unless column_exists?(:users, :additional_info)
  end
end
