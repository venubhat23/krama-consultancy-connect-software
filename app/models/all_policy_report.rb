class AllPolicyReport < ApplicationRecord
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id', optional: true

  validates :name, presence: true

  # report_data is a JSON column, no need for serialize in Rails with json column type
end