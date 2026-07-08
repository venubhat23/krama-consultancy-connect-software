class AddNotificationDatesToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :notification_dates, :text unless column_exists?(:motor_insurances, :notification_dates)
  end
end
