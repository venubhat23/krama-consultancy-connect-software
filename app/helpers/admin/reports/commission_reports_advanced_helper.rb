module Admin::Reports::CommissionReportsAdvancedHelper
  def get_insurance_company(commission)
    commission.policy&.insurance_company_name
  end

  def get_sub_agent_name(commission)
    commission.policy&.sub_agent&.full_name
  end

  def get_distributor_name(commission)
    commission.policy&.distributor&.full_name
  end
end