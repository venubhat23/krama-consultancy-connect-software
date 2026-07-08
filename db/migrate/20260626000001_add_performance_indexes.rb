class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # life_insurances: sub_agent_id and DRWISE composite are missing
    unless index_exists?(:life_insurances, :sub_agent_id)
      add_index :life_insurances, :sub_agent_id, name: 'index_life_insurances_on_sub_agent_id'
    end
    unless index_exists?(:life_insurances, %i[is_admin_added is_customer_added is_agent_added])
      add_index :life_insurances, %i[is_admin_added is_customer_added is_agent_added],
                name: 'idx_life_insurances_drwise'
    end

    # motor_insurances: sub_agent_id, investor_id, distributor_id, agency_code_id, DRWISE composite
    unless index_exists?(:motor_insurances, :sub_agent_id)
      add_index :motor_insurances, :sub_agent_id, name: 'index_motor_insurances_on_sub_agent_id'
    end
    unless index_exists?(:motor_insurances, :investor_id)
      add_index :motor_insurances, :investor_id, name: 'index_motor_insurances_on_investor_id'
    end
    unless index_exists?(:motor_insurances, :distributor_id)
      add_index :motor_insurances, :distributor_id, name: 'index_motor_insurances_on_distributor_id'
    end
    unless index_exists?(:motor_insurances, :agency_code_id)
      add_index :motor_insurances, :agency_code_id, name: 'index_motor_insurances_on_agency_code_id'
    end
    unless index_exists?(:motor_insurances, %i[is_admin_added is_customer_added is_agent_added])
      add_index :motor_insurances, %i[is_admin_added is_customer_added is_agent_added],
                name: 'idx_motor_insurances_drwise'
    end

    # other_insurances: customer_id standalone, sub_agent_id, DRWISE composite
    unless index_exists?(:other_insurances, :customer_id)
      add_index :other_insurances, :customer_id, name: 'index_other_insurances_on_customer_id'
    end
    unless index_exists?(:other_insurances, :sub_agent_id)
      add_index :other_insurances, :sub_agent_id, name: 'index_other_insurances_on_sub_agent_id'
    end
    unless index_exists?(:other_insurances, :distributor_id)
      add_index :other_insurances, :distributor_id, name: 'index_other_insurances_on_distributor_id'
    end
    unless index_exists?(:other_insurances, %i[is_admin_added is_customer_added is_agent_added])
      add_index :other_insurances, %i[is_admin_added is_customer_added is_agent_added],
                name: 'idx_other_insurances_drwise'
    end

    # health_insurances: status and DRWISE composite (sub_agent_id already exists)
    unless index_exists?(:health_insurances, :status)
      add_index :health_insurances, :status, name: 'index_health_insurances_on_status'
    end
    unless index_exists?(:health_insurances, %i[is_admin_added is_customer_added is_agent_added])
      add_index :health_insurances, %i[is_admin_added is_customer_added is_agent_added],
                name: 'idx_health_insurances_drwise'
    end

    # payouts: customer_id for commission_tracking queries
    unless index_exists?(:payouts, :customer_id)
      add_index :payouts, :customer_id, name: 'index_payouts_on_customer_id'
    end

    # leads: policy_created_id
    unless index_exists?(:leads, :policy_created_id)
      add_index :leads, :policy_created_id, name: 'index_leads_on_policy_created_id'
    end

    # Remove duplicate indexes on commission_payouts (keep the named ones, drop the generic ones)
    if index_exists?(:commission_payouts, %i[policy_type policy_id], name: 'index_commission_payouts_on_policy_type_and_policy_id')
      remove_index :commission_payouts, name: 'index_commission_payouts_on_policy_type_and_policy_id'
    end
    if index_exists?(:commission_payouts, %i[payout_to status], name: 'index_commission_payouts_on_payout_to_and_status')
      remove_index :commission_payouts, name: 'index_commission_payouts_on_payout_to_and_status'
    end
  end
end
