class AddAnniversaryDateToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :anniversary_date, :date
  end
end
