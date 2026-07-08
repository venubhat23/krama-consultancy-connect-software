class CreateClientServices < ActiveRecord::Migration[7.1]
  def change
    create_table :client_services do |t|
      t.string   :service_type,     null: false
      t.string   :service_category, null: false
      t.bigint   :customer_id,      null: false
      t.bigint   :sub_agent_id
      t.bigint   :distributor_id
      t.decimal  :amount,           precision: 15, scale: 2, default: 0.0
      t.string   :status,           default: 'pending'
      t.string   :reference_number
      t.date     :start_date
      t.text     :notes

      # Main agent commission
      t.decimal :main_agent_commission_percentage, precision: 8, scale: 2, default: 0.0
      t.decimal :commission_amount,                precision: 15, scale: 2, default: 0.0
      t.decimal :tds_percentage,                   precision: 8, scale: 2, default: 0.0
      t.decimal :tds_amount,                       precision: 15, scale: 2, default: 0.0
      t.decimal :after_tds_value,                  precision: 15, scale: 2, default: 0.0

      # Affiliate (sub-agent) commission
      t.decimal :sub_agent_commission_percentage, precision: 8, scale: 2, default: 2.0
      t.decimal :sub_agent_commission_amount,     precision: 15, scale: 2, default: 0.0
      t.decimal :sub_agent_tds_percentage,        precision: 8, scale: 2, default: 0.0
      t.decimal :sub_agent_tds_amount,            precision: 15, scale: 2, default: 0.0
      t.decimal :sub_agent_after_tds_value,       precision: 15, scale: 2, default: 0.0

      # Ambassador (distributor) commission
      t.decimal :distributor_commission_percentage, precision: 8, scale: 2, default: 0.0
      t.decimal :distributor_commission_amount,     precision: 15, scale: 2, default: 0.0
      t.decimal :distributor_tds_percentage,        precision: 8, scale: 2, default: 0.0
      t.decimal :distributor_tds_amount,            precision: 15, scale: 2, default: 0.0
      t.decimal :distributor_after_tds_value,       precision: 15, scale: 2, default: 0.0

      # Investor commission
      t.decimal :investor_commission_percentage, precision: 8, scale: 2, default: 2.0
      t.decimal :investor_commission_amount,     precision: 15, scale: 2, default: 0.0

      # Company & profit
      t.decimal :company_expenses_percentage, precision: 8, scale: 2, default: 0.0
      t.decimal :company_expenses_amount,     precision: 15, scale: 2, default: 0.0
      t.decimal :total_distribution_percentage, precision: 8, scale: 2, default: 0.0
      t.decimal :profit_percentage,             precision: 8, scale: 2, default: 0.0
      t.decimal :profit_amount,                 precision: 15, scale: 2, default: 0.0

      t.timestamps
    end

    add_index :client_services, :customer_id
    add_index :client_services, :service_type
    add_index :client_services, :service_category
    add_index :client_services, :sub_agent_id
  end
end
