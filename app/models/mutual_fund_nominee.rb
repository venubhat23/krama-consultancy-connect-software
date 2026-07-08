class MutualFundNominee < ApplicationRecord
  belongs_to :mutual_fund

  validates :nominee_name, presence: true
end
