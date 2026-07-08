class AddNotificationDatesToInsurance < ActiveRecord::Migration[8.0]
  def change
    add_column :health_insurances, :notification_dates, :text
    add_column :life_insurances, :notification_dates, :text
    add_column :motor_insurances, :notification_dates, :text
    add_column :other_insurances, :notification_dates, :text
  end
end
