class CreateMutualFunds < ActiveRecord::Migration[7.1]
  def change
    create_table :mutual_funds do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :sub_agent, foreign_key: { to_table: :sub_agents }, null: true
      t.references :distributor, foreign_key: true, null: true

      # Investment details
      t.string :investment_type, null: false  # SIP or Lumpsum
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :fund_name  # AMC / Fund house name
      t.string :folio_number
      t.string :plan_name
      t.date :start_date
      t.date :maturity_date

      # Bank details
      t.string :bank_name
      t.string :account_type
      t.string :account_number
      t.string :ifsc_code
      t.string :account_holder_name

      # Other details
      t.string :reference_by_name
      t.string :broker_name
      t.decimal :bonus, precision: 15, scale: 2, default: 0
      t.decimal :fund, precision: 15, scale: 2, default: 0
      t.text :extra_note

      # Commission fields - Main Agent
      t.decimal :main_agent_commission_percentage, precision: 8, scale: 2, default: 0
      t.decimal :commission_amount, precision: 15, scale: 2, default: 0
      t.decimal :tds_percentage, precision: 8, scale: 2, default: 0
      t.decimal :tds_amount, precision: 15, scale: 2, default: 0
      t.decimal :after_tds_value, precision: 15, scale: 2, default: 0

      # Commission fields - Affiliate (sub_agent)
      t.decimal :sub_agent_commission_percentage, precision: 8, scale: 2, default: 2
      t.decimal :sub_agent_commission_amount, precision: 15, scale: 2, default: 0
      t.decimal :sub_agent_tds_percentage, precision: 8, scale: 2, default: 0
      t.decimal :sub_agent_tds_amount, precision: 15, scale: 2, default: 0
      t.decimal :sub_agent_after_tds_value, precision: 15, scale: 2, default: 0

      # Commission fields - Ambassador (distributor)
      t.decimal :distributor_commission_percentage, precision: 8, scale: 2, default: 0
      t.decimal :distributor_commission_amount, precision: 15, scale: 2, default: 0
      t.decimal :distributor_tds_percentage, precision: 8, scale: 2, default: 0
      t.decimal :distributor_tds_amount, precision: 15, scale: 2, default: 0
      t.decimal :distributor_after_tds_value, precision: 15, scale: 2, default: 0

      # Commission fields - Investor
      t.decimal :investor_commission_percentage, precision: 8, scale: 2, default: 2
      t.decimal :investor_commission_amount, precision: 15, scale: 2, default: 0

      # Commission fields - Company expenses
      t.decimal :company_expenses_percentage, precision: 8, scale: 2, default: 0
      t.decimal :company_expenses_amount, precision: 15, scale: 2, default: 0

      # Commission summary
      t.decimal :total_distribution_percentage, precision: 8, scale: 2, default: 0
      t.decimal :profit_percentage, precision: 8, scale: 2, default: 0
      t.decimal :profit_amount, precision: 15, scale: 2, default: 0

      # R2 main document storage
      t.string :main_policy_document_key
      t.string :main_policy_document_filename
      t.string :main_policy_document_content_type
      t.bigint :main_policy_document_size

      # Autopay installment
      t.date :installment_autopay_start_date
      t.date :installment_autopay_end_date

      # Status flags
      t.boolean :is_admin_added, default: false
      t.boolean :is_customer_added, default: false
      t.boolean :is_agent_added, default: false
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
