class EnhanceCommissionPayoutSystem < ActiveRecord::Migration[8.0]
  def change
    # Add missing fields to commission_payouts table
    add_column :commission_payouts, :transaction_id, :string
    add_column :commission_payouts, :payment_mode, :string
    add_column :commission_payouts, :reference_number, :string
    add_column :commission_payouts, :commission_amount_received, :decimal, precision: 10, scale: 2
    add_column :commission_payouts, :distribution_percentage, :decimal, precision: 5, scale: 2
    add_column :commission_payouts, :notes, :text
    add_column :commission_payouts, :processed_by, :string
    add_column :commission_payouts, :processed_at, :datetime

    # Create new table for tracking commission receipt from insurance companies
    create_table :commission_receipts do |t|
      t.string :policy_type, null: false  # health, life, motor, other
      t.integer :policy_id, null: false
      t.decimal :total_commission_received, precision: 12, scale: 2, null: false
      t.date :received_date, null: false
      t.string :insurance_company_name
      t.string :insurance_company_reference
      t.decimal :company_commission_percentage, precision: 5, scale: 2
      t.string :payment_mode # bank_transfer, cheque, online
      t.string :transaction_id
      t.text :notes
      t.string :received_by # who recorded this entry
      t.boolean :auto_distributed, default: false
      t.datetime :distributed_at

      t.timestamps
    end

    # Create table for tracking distribution breakdowns
    create_table :payout_distributions do |t|
      t.references :commission_receipt, null: false, foreign_key: true
      t.string :recipient_type, null: false # sub_agent, distributor, investor
      t.integer :recipient_id
      t.decimal :distribution_percentage, precision: 5, scale: 2, null: false
      t.decimal :calculated_amount, precision: 10, scale: 2, null: false
      t.decimal :paid_amount, precision: 10, scale: 2, default: 0.0
      t.decimal :pending_amount, precision: 10, scale: 2, default: 0.0
      t.string :status, default: 'pending' # pending, partial, paid
      t.date :payment_date
      t.string :payment_mode
      t.string :transaction_id
      t.string :reference_number
      t.text :payment_notes
      t.string :processed_by

      t.timestamps
    end

    # Create table for audit trail
    create_table :payout_audit_logs do |t|
      t.string :auditable_type
      t.integer :auditable_id
      t.string :action # created, updated, paid, cancelled
      t.json :changes # store what was changed
      t.string :performed_by
      t.string :ip_address
      t.text :notes

      t.timestamps
    end

    # Add indexes for better performance
    add_index :commission_payouts, [:policy_type, :policy_id]
    add_index :commission_payouts, [:payout_to, :status]
    add_index :commission_payouts, :payout_date

    add_index :commission_receipts, [:policy_type, :policy_id], unique: true
    add_index :commission_receipts, :received_date
    add_index :commission_receipts, :auto_distributed

    add_index :payout_distributions, [:recipient_type, :recipient_id]
    add_index :payout_distributions, :status
    add_index :payout_distributions, :payment_date

    add_index :payout_audit_logs, [:auditable_type, :auditable_id]
    add_index :payout_audit_logs, :performed_by
    add_index :payout_audit_logs, :created_at
  end
end