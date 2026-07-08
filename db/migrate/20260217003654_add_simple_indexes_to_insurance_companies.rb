class AddSimpleIndexesToInsuranceCompanies < ActiveRecord::Migration[8.0]
  def change
    # Only add indexes that don't exist from previous migration
    if column_exists?(:insurance_companies, :insurance_type) && !index_exists?(:insurance_companies, :insurance_type)
      add_index :insurance_companies, :insurance_type, name: 'idx_insurance_companies_type'
    end

    unless index_exists?(:insurance_companies, :status)
      add_index :insurance_companies, :status, name: 'idx_insurance_companies_status'
    end

    unless index_exists?(:insurance_companies, :name)
      add_index :insurance_companies, :name, name: 'idx_insurance_companies_name'
    end

    unless index_exists?(:insurance_companies, :code)
      add_index :insurance_companies, :code, name: 'idx_insurance_companies_code'
    end

    unless index_exists?(:insurance_companies, :contact_person)
      add_index :insurance_companies, :contact_person, name: 'idx_insurance_companies_contact_person'
    end

    if column_exists?(:insurance_companies, :insurance_type)
      add_index :insurance_companies, [:insurance_type, :status], name: 'idx_insurance_companies_type_status' unless index_exists?(:insurance_companies, [:insurance_type, :status])
      add_index :insurance_companies, [:status, :insurance_type], name: 'idx_insurance_companies_status_type' unless index_exists?(:insurance_companies, [:status, :insurance_type])
    end

    # Indexes for sorting and pagination
    unless index_exists?(:insurance_companies, [:name, :id])
      add_index :insurance_companies, [:name, :id], name: 'idx_insurance_companies_name_id'
    end

    unless index_exists?(:insurance_companies, :created_at)
      add_index :insurance_companies, :created_at, name: 'idx_insurance_companies_created_at'
    end

    unless index_exists?(:insurance_companies, :updated_at)
      add_index :insurance_companies, :updated_at, name: 'idx_insurance_companies_updated_at'
    end
  end
end
