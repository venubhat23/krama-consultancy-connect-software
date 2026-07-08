class RecreateLifeInsurancesTableWithComprehensiveStructure < ActiveRecord::Migration[8.0]
  def change
    # First, remove foreign key constraint if it exists
    remove_foreign_key :life_insurances, :policies if foreign_key_exists?(:life_insurances, :policies)

    # Drop the existing life_insurances table
    drop_table :life_insurances if table_exists?(:life_insurances)

    # Create the new comprehensive life_insurances table
    create_table :life_insurances do |t|
      # Client & Agent Details
      t.references :customer, null: false, foreign_key: true
      t.references :sub_agent, null: true, foreign_key: true
      t.string :policy_holder, null: false
      t.string :insured_name

      # Policy Details
      t.string :insurance_company_name, null: false
      t.references :agency_code, null: true, foreign_key: true
      t.references :broker, null: true, foreign_key: true
      t.string :policy_type, null: false
      t.string :payment_mode, null: false
      t.string :policy_number, null: false
      t.date :policy_booking_date
      t.date :policy_start_date, null: false
      t.date :policy_end_date, null: false
      t.date :risk_start_date
      t.integer :policy_term, null: false
      t.integer :premium_payment_term, null: false
      t.string :plan_name
      t.decimal :sum_insured, precision: 15, scale: 2, null: false
      t.decimal :net_premium, precision: 15, scale: 2, null: false

      # GST Details
      t.decimal :first_year_gst_percentage, precision: 5, scale: 2, default: 18.0
      t.decimal :second_year_gst_percentage, precision: 5, scale: 2, default: 0.0
      t.decimal :third_year_gst_percentage, precision: 5, scale: 2, default: 0.0
      t.decimal :total_premium, precision: 15, scale: 2, null: false

      # Rider Details
      t.decimal :term_rider_amount, precision: 15, scale: 2, default: 0.0
      t.text :term_rider_note
      t.decimal :critical_illness_rider_amount, precision: 15, scale: 2, default: 0.0
      t.text :critical_illness_rider_note
      t.decimal :accident_rider_amount, precision: 15, scale: 2, default: 0.0
      t.text :accident_rider_note
      t.decimal :pwb_rider_amount, precision: 15, scale: 2, default: 0.0
      t.text :pwb_rider_note
      t.decimal :other_rider_amount, precision: 15, scale: 2, default: 0.0
      t.text :other_rider_note

      # Nominee Details
      t.string :nominee_name
      t.string :nominee_relationship
      t.integer :nominee_age

      # Bank Details
      t.string :bank_name
      t.string :account_type
      t.string :account_number
      t.string :ifsc_code
      t.string :account_holder_name

      # Other Details
      t.string :reference_by_name
      t.string :broker_name
      t.decimal :bonus, precision: 15, scale: 2, default: 0.0
      t.decimal :fund, precision: 15, scale: 2, default: 0.0
      t.text :extra_note

      # Commission Details
      t.decimal :main_agent_commission_percentage, precision: 5, scale: 2, default: 0.0
      t.decimal :commission_amount, precision: 15, scale: 2, default: 0.0
      t.decimal :tds_percentage, precision: 5, scale: 2, default: 0.0
      t.decimal :tds_amount, precision: 15, scale: 2, default: 0.0
      t.decimal :after_tds_value, precision: 15, scale: 2, default: 0.0

      # Autopay Details
      t.date :installment_autopay_start_date
      t.date :installment_autopay_end_date

      # Status and metadata
      t.boolean :active, default: true

      t.timestamps
    end

    # Add indexes
    add_index :life_insurances, :policy_number, unique: true
    add_index :life_insurances, :insurance_company_name
    add_index :life_insurances, :policy_type
    add_index :life_insurances, :policy_start_date
    add_index :life_insurances, :policy_end_date
    add_index :life_insurances, [:policy_start_date, :policy_end_date]
  end
end
