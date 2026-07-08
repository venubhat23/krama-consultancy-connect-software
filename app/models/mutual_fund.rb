class MutualFund < ApplicationRecord
  belongs_to :customer
  belongs_to :sub_agent, class_name: 'SubAgent', optional: true
  belongs_to :distributor, optional: true

  has_many :mutual_fund_nominees, dependent: :destroy
  has_many :policy_documents_records, -> { where(policy_type: 'mutual_fund') },
           class_name: 'PolicyDocument',
           foreign_key: 'policy_id',
           dependent: :destroy

  accepts_nested_attributes_for :mutual_fund_nominees, allow_destroy: true

  attr_accessor :main_policy_document

  INVESTMENT_TYPES = ['SIP', 'Lumpsum'].freeze
  ACCOUNT_TYPES = ['Savings', 'Current', 'Salary', 'Business'].freeze
  RELATIONSHIPS = ['Spouse', 'Father', 'Mother', 'Son', 'Daughter', 'Brother', 'Sister', 'Other'].freeze

  validates :customer_id, presence: true
  validates :investment_type, presence: true, inclusion: { in: INVESTMENT_TYPES }
  validates :amount, presence: true, numericality: { greater_than: 0 }

  scope :drwise, -> { where(is_admin_added: true, is_customer_added: false, is_agent_added: false) }
  scope :non_drwise, -> {
    where(
      '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
      true, false, false, true, false, false
    )
  }
  scope :active_records, -> { where(active: true) }

  def display_name
    "#{customer&.display_name} - #{fund_name} (#{investment_type})"
  end

  def upload_main_policy_to_r2(file)
    result = R2Service.upload(file, folder: "mutual_fund/#{id}")
    return false if result[:error]

    update!(
      main_policy_document_key: result[:key],
      main_policy_document_filename: result[:filename],
      main_policy_document_content_type: result[:content_type],
      main_policy_document_size: result[:size]
    )
    result
  end

  def delete_main_policy_from_r2
    return unless main_policy_document_key.present?

    R2Service.delete(main_policy_document_key)
    update!(
      main_policy_document_key: nil,
      main_policy_document_filename: nil,
      main_policy_document_content_type: nil,
      main_policy_document_size: nil
    )
  end

  def has_main_policy_r2_document?
    main_policy_document_key.present?
  end

  def main_policy_r2_url
    return nil unless main_policy_document_key.present?
    R2Service.public_url(main_policy_document_key)
  end
end
