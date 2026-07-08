module DashboardHelper
  def get_consistent_renewal_counts
    {
      expiring: get_expiring_policies_count(30),
      expired: get_all_expired_policies_count,
      processed: get_processed_this_month_count
    }
  end

  def get_expiring_policies_count(days = 30)
    count = 0
    date_range = Date.current..(days.days.from_now)

    count += HealthInsurance.where(policy_end_date: date_range).count rescue 0
    count += LifeInsurance.where(policy_end_date: date_range).count rescue 0
    count += MotorInsurance.where(policy_end_date: date_range).count rescue 0
    count += OtherInsurance.where(policy_end_date: date_range).count rescue 0

    count
  end

  def get_all_expired_policies_count
    count = 0

    count += HealthInsurance.where('policy_end_date < ?', Date.current).count rescue 0
    count += LifeInsurance.where('policy_end_date < ?', Date.current).count rescue 0
    count += MotorInsurance.where('policy_end_date < ?', Date.current).count rescue 0
    count += OtherInsurance.where('policy_end_date < ?', Date.current).count rescue 0

    count
  end

  def get_processed_this_month_count
    count = 0
    current_month_start = Date.current.beginning_of_month

    count += HealthInsurance.where('created_at >= ?', current_month_start).where(policy_type: 'Renewal').count rescue 0
    count += LifeInsurance.where('created_at >= ?', current_month_start).where(policy_type: 'Renewal').count rescue 0
    count += MotorInsurance.where('created_at >= ?', current_month_start).where(policy_type: 'Renewal').count rescue 0
    count += OtherInsurance.where('created_at >= ?', current_month_start).where(policy_type: 'Renewal').count rescue 0

    count
  end

  def get_health_policy_alerts
    {
      expiring_soon: HealthInsurance.where(policy_end_date: Date.current..30.days.from_now).count,
      expired_month: HealthInsurance.where('policy_end_date < ?', Date.current).count,
      opportunities: get_health_renewal_opportunities_count
    }
  end

  def get_health_renewal_opportunities_count
    expired_policies = HealthInsurance.where(policy_end_date: 60.days.ago..Date.current)
                                     .where(policy_type: ['New', nil])

    count = 0
    expired_policies.each do |policy|
      renewal_exists = HealthInsurance.where(
        customer_id: policy.customer_id,
        policy_type: 'Renewal',
        created_at: policy.policy_end_date..Date.current
      ).exists?

      count += 1 unless renewal_exists
    end

    count
  rescue
    0
  end
end
