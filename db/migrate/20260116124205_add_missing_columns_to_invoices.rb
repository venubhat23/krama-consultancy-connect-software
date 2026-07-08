class AddMissingColumnsToInvoices < ActiveRecord::Migration[8.0]
  def change
    # Add all missing columns from the original invoice migration
    # For required columns on existing table, we'll add them as nullable first, then set defaults
    add_column :invoices, :invoice_number, :string unless column_exists?(:invoices, :invoice_number)
    add_column :invoices, :payout_type, :string unless column_exists?(:invoices, :payout_type)
    add_column :invoices, :payout_id, :integer unless column_exists?(:invoices, :payout_id)
    add_column :invoices, :total_amount, :decimal, precision: 10, scale: 2 unless column_exists?(:invoices, :total_amount)
    add_column :invoices, :status, :string, default: 'pending' unless column_exists?(:invoices, :status)
    add_column :invoices, :invoice_date, :date unless column_exists?(:invoices, :invoice_date)
    add_column :invoices, :due_date, :date unless column_exists?(:invoices, :due_date)
    add_column :invoices, :paid_at, :datetime unless column_exists?(:invoices, :paid_at)
    add_column :invoices, :recipient_name, :string unless column_exists?(:invoices, :recipient_name)
    add_column :invoices, :recipient_email, :string unless column_exists?(:invoices, :recipient_email)
    add_column :invoices, :recipient_address, :text unless column_exists?(:invoices, :recipient_address)
    add_column :invoices, :notes, :text unless column_exists?(:invoices, :notes)

    # Set default values for existing records if any
    execute <<-SQL
      UPDATE invoices SET
        invoice_number = 'INV-' || id || '-' || EXTRACT(YEAR FROM created_at),
        payout_type = 'commission',
        payout_id = 1,
        total_amount = 0.0,
        status = 'pending',
        invoice_date = created_at::date,
        due_date = (created_at + INTERVAL '30 days')::date
      WHERE invoice_number IS NULL;
    SQL

    # Add indexes if they don't exist
    add_index :invoices, :invoice_number, unique: true unless index_exists?(:invoices, :invoice_number)
    add_index :invoices, [:payout_type, :payout_id] unless index_exists?(:invoices, [:payout_type, :payout_id])
    add_index :invoices, :status unless index_exists?(:invoices, :status)
    add_index :invoices, :invoice_date unless index_exists?(:invoices, :invoice_date)
  end
end
