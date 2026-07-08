class FixSystemSettingsStructure < ActiveRecord::Migration[8.0]
  def up
    # Add the missing columns that should have been in the original table
    add_column :system_settings, :key, :string unless column_exists?(:system_settings, :key)
    add_column :system_settings, :value, :text unless column_exists?(:system_settings, :value)
    add_column :system_settings, :description, :text unless column_exists?(:system_settings, :description)
    add_column :system_settings, :setting_type, :string unless column_exists?(:system_settings, :setting_type)
    add_column :system_settings, :default_main_agent_commission, :decimal, precision: 5, scale: 2 unless column_exists?(:system_settings, :default_main_agent_commission)
    add_column :system_settings, :default_affiliate_commission, :decimal, precision: 5, scale: 2 unless column_exists?(:system_settings, :default_affiliate_commission)
    add_column :system_settings, :default_ambassador_commission, :decimal, precision: 5, scale: 2 unless column_exists?(:system_settings, :default_ambassador_commission)
    add_column :system_settings, :default_company_expenses, :decimal, precision: 5, scale: 2 unless column_exists?(:system_settings, :default_company_expenses)
    add_column :system_settings, :terms_and_conditions, :text unless column_exists?(:system_settings, :terms_and_conditions)

    # Add index on key column if it doesn't exist
    add_index :system_settings, :key, unique: true unless index_exists?(:system_settings, :key)

    # Migrate existing data if any exists in the old structure
    existing_records = execute("SELECT count(*) as count FROM system_settings").first
    if existing_records['count'] && existing_records['count'].to_i > 0
      # If there are existing records with the old structure, we need to migrate them
      puts "Migrating existing system_settings records..."

      # Get first existing record to preserve company info
      first_record = execute("SELECT * FROM system_settings LIMIT 1").first
      if first_record && first_record['company_name']
        # Create system config record with company information
        execute(<<-SQL)
          INSERT INTO system_settings (
            key, value, description, setting_type,
            default_main_agent_commission, default_affiliate_commission,
            default_ambassador_commission, default_company_expenses,
            terms_and_conditions, created_at, updated_at
          ) VALUES (
            'system_config',
            'system configuration',
            'System configuration settings including company information',
            'configuration',
            0.0, 0.0, 0.0, 2.0, '',
            NOW(), NOW()
          ) ON CONFLICT DO NOTHING;
        SQL
      end

      # Clear old records after migration
      puts "Clearing old structure records..."
      execute("DELETE FROM system_settings WHERE key IS NULL OR key = ''")
    end

    # Create default pagination setting if it doesn't exist
    execute(<<-SQL)
      INSERT INTO system_settings (key, value, description, setting_type, created_at, updated_at)
      SELECT 'default_pagination_per_page', '10', 'Default number of records per page for all index pages', 'integer', NOW(), NOW()
      WHERE NOT EXISTS (SELECT 1 FROM system_settings WHERE key = 'default_pagination_per_page');
    SQL

    # Create company expenses percentage setting if it doesn't exist
    execute(<<-SQL)
      INSERT INTO system_settings (key, value, description, setting_type, created_at, updated_at)
      SELECT 'company_expenses_percentage', '2.0', 'Company expenses percentage that can be configured by admin', 'percentage', NOW(), NOW()
      WHERE NOT EXISTS (SELECT 1 FROM system_settings WHERE key = 'company_expenses_percentage');
    SQL

    puts "System settings structure has been fixed successfully!"
  end

  def down
    # Remove the columns we added (but keep data)
    remove_column :system_settings, :key if column_exists?(:system_settings, :key)
    remove_column :system_settings, :value if column_exists?(:system_settings, :value)
    remove_column :system_settings, :description if column_exists?(:system_settings, :description)
    remove_column :system_settings, :setting_type if column_exists?(:system_settings, :setting_type)
    remove_column :system_settings, :default_main_agent_commission if column_exists?(:system_settings, :default_main_agent_commission)
    remove_column :system_settings, :default_affiliate_commission if column_exists?(:system_settings, :default_affiliate_commission)
    remove_column :system_settings, :default_ambassador_commission if column_exists?(:system_settings, :default_ambassador_commission)
    remove_column :system_settings, :default_company_expenses if column_exists?(:system_settings, :default_company_expenses)
    remove_column :system_settings, :terms_and_conditions if column_exists?(:system_settings, :terms_and_conditions)
  end
end