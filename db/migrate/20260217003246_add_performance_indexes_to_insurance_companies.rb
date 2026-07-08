class AddPerformanceIndexesToInsuranceCompanies < ActiveRecord::Migration[8.0]
  def change
    # Primary indexes for filtering and search
    add_index :insurance_companies, :insurance_type, name: 'idx_insurance_companies_type' if column_exists?(:insurance_companies, :insurance_type)
    add_index :insurance_companies, :status, name: 'idx_insurance_companies_status'
    add_index :insurance_companies, :name, name: 'idx_insurance_companies_name'
    add_index :insurance_companies, :code, name: 'idx_insurance_companies_code'

    # Compound indexes for common query patterns
    if column_exists?(:insurance_companies, :insurance_type)
      add_index :insurance_companies, [:insurance_type, :status], name: 'idx_insurance_companies_type_status'
      add_index :insurance_companies, [:status, :insurance_type], name: 'idx_insurance_companies_status_type'
    end

    # Text search indexes (PostgreSQL specific)
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      begin
        # Try to enable pg_trgm extension first
        execute "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

        # GIN indexes for fast text search (only if pg_trgm is available)
        execute "CREATE INDEX idx_insurance_companies_name_gin ON insurance_companies USING gin(name gin_trgm_ops);"
        execute "CREATE INDEX idx_insurance_companies_code_gin ON insurance_companies USING gin(code gin_trgm_ops);"
        execute "CREATE INDEX idx_insurance_companies_contact_gin ON insurance_companies USING gin(contact_person gin_trgm_ops);"
      rescue => e
        puts "Note: Advanced text search indexes skipped: #{e.message}"
        # Fall back to regular B-tree indexes for text search
        add_index :insurance_companies, :contact_person, name: 'idx_insurance_companies_contact_person'
      end
    else
      # For non-PostgreSQL databases, use regular indexes
      add_index :insurance_companies, :contact_person, name: 'idx_insurance_companies_contact_person'
    end

    # Composite index for search queries
    add_index :insurance_companies, [:name, :code, :contact_person], name: 'idx_insurance_companies_search_composite'

    # Indexes for sorting and pagination
    add_index :insurance_companies, [:name, :id], name: 'idx_insurance_companies_name_id'
    add_index :insurance_companies, :created_at, name: 'idx_insurance_companies_created_at'
    add_index :insurance_companies, :updated_at, name: 'idx_insurance_companies_updated_at'
  end
end
