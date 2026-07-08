class CorporateMember < ApplicationRecord
  belongs_to :customer
  has_many :documents, as: :documentable, dependent: :destroy

  validates :company_name, presence: true

  accepts_nested_attributes_for :documents, allow_destroy: true, reject_if: :all_blank

  def display_name
    company_name
  end
end