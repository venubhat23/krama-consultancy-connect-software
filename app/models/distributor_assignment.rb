class DistributorAssignment < ApplicationRecord
  belongs_to :distributor
  belongs_to :sub_agent

  validates :distributor_id, presence: true
  validates :sub_agent_id, presence: true, uniqueness: { scope: :distributor_id }

  before_create :set_assigned_at

  private

  def set_assigned_at
    self.assigned_at ||= Time.current
  end
end
