module Admin
  module Api
    class SystemStatusController < Admin::ApplicationController
      skip_before_action :verify_authenticity_token

      def active_affiliates
        begin
          # Match dashboard card: only SubAgents that have at least one policy (any insurance type)
          active_ids = []
          begin
            ids = ActiveRecord::Base.connection.select_values("
              SELECT DISTINCT sub_agent_id FROM (
                SELECT sub_agent_id FROM health_insurances WHERE sub_agent_id IS NOT NULL
                UNION
                SELECT sub_agent_id FROM life_insurances WHERE sub_agent_id IS NOT NULL
                UNION
                SELECT sub_agent_id FROM motor_insurances WHERE sub_agent_id IS NOT NULL
              ) AS t
            ")
            active_ids = ids.map(&:to_i)
          rescue => e
            Rails.logger.error "Error fetching active affiliate ids: #{e.message}"
          end

          affiliates = SubAgent.where(id: active_ids).order(:id)

          affiliate_data = []

          affiliates.find_each do |affiliate|
            begin
              policies_count = calculate_affiliate_policies(affiliate)

              # Only include affiliates with at least one policy
              next if policies_count == 0

              name = affiliate.full_name
              name = "#{affiliate.first_name} #{affiliate.last_name}".strip if name.blank? && (affiliate.first_name.present? || affiliate.last_name.present?)
              name = "Affiliate ##{affiliate.id}" if name.blank?

              affiliate_data << {
                id: affiliate.id,
                name: name,
                email: affiliate.email || 'N/A',
                phone: affiliate.mobile || affiliate.phone || 'N/A',
                status: affiliate.status || 'active',
                joined_date: affiliate.created_at ? affiliate.created_at.strftime('%d %b %Y') : 'N/A',
                total_policies: policies_count,
                total_premium: calculate_affiliate_premium(affiliate),
                commission_pending: calculate_affiliate_commission(affiliate, 'pending'),
                commission_paid: calculate_affiliate_commission(affiliate, 'paid')
              }
            rescue => e
              Rails.logger.error "Error processing affiliate #{affiliate.id}: #{e.message}"
              Rails.logger.error e.backtrace.first(3).join("\n") if e.backtrace
              next
            end
          end

          render json: {
            success: true,
            affiliates: affiliate_data,
            summary: {
              total_active: affiliate_data.length,
              total_policies: affiliate_data.sum { |a| a[:total_policies] },
              total_premium: affiliate_data.sum { |a| a[:total_premium] },
              total_commission_pending: affiliate_data.sum { |a| a[:commission_pending] },
              total_commission_paid: affiliate_data.sum { |a| a[:commission_paid] }
            }
          }
        rescue => e
          Rails.logger.error "Error in active_affiliates: #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n") if e.backtrace

          render json: {
            success: false,
            error: e.message,
            affiliates: [],
            summary: {
              total_active: 0,
              total_policies: 0,
              total_premium: 0,
              total_commission_pending: 0,
              total_commission_paid: 0
            }
          }, status: 500
        end
      end

      def lead_conversion
        begin
          # Single query for stage breakdown + summary counts
          stage_breakdown = Lead.group(:current_stage).count

          total_leads     = stage_breakdown.values.sum
          converted_leads = stage_breakdown['converted'].to_i
          pending_leads   = stage_breakdown.reject { |s, _| ['converted', 'lost', 'rejected'].include?(s) }.values.sum

          conversion_rate = total_leads > 0 ? ((converted_leads.to_f / total_leads) * 100).round(2) : 0

          summary = {
            total_leads: total_leads,
            converted_leads: converted_leads,
            pending_leads: pending_leads,
            conversion_rate: conversion_rate
          }

          # Single query for monthly trend (last 6 months)
          six_months_ago = 6.months.ago.beginning_of_month
          rows = Lead.where(created_at: six_months_ago..Time.current.end_of_month)
                     .group("DATE_TRUNC('month', created_at)")
                     .select(
                       "DATE_TRUNC('month', created_at) AS month_date",
                       "COUNT(*) AS total",
                       "SUM(CASE WHEN current_stage = 'converted' THEN 1 ELSE 0 END) AS converted"
                     )

          monthly_map = rows.each_with_object({}) do |row, h|
            h[row.month_date.to_date.beginning_of_month] = { total: row.total.to_i, converted: row.converted.to_i }
          end

          monthly_trend = 6.times.map do |i|
            month_start = i.months.ago.beginning_of_month.to_date
            d = monthly_map[month_start] || { total: 0, converted: 0 }
            rate = d[:total] > 0 ? ((d[:converted].to_f / d[:total]) * 100).round(2) : 0
            { month: month_start.strftime('%B %Y'), total_leads: d[:total], converted_leads: d[:converted], conversion_rate: rate }
          end.reverse

          # Single query for source-wise conversion
          source_rows = Lead.where.not(lead_source: [nil, ''])
                            .group(:lead_source)
                            .select(
                              "lead_source AS source",
                              "COUNT(*) AS total",
                              "SUM(CASE WHEN current_stage = 'converted' THEN 1 ELSE 0 END) AS converted"
                            )

          source_conversion = source_rows.map do |row|
            total = row.total.to_i
            converted = row.converted.to_i
            { source: row.source, total: total, converted: converted,
              rate: total > 0 ? ((converted.to_f / total) * 100).round(2) : 0 }
          end

          render json: {
            success: true,
            summary: summary,
            stage_breakdown: stage_breakdown,
            monthly_trend: monthly_trend,
            source_conversion: source_conversion,
            calculation_method: "Conversion Rate = (Converted Leads / Total Leads) × 100"
          }
        rescue => e
          Rails.logger.error "Error in lead_conversion: #{e.message}"
          render json: {
            success: false,
            error: "Unable to load lead conversion data",
            summary: { total_leads: 0, converted_leads: 0, pending_leads: 0, conversion_rate: 0 }
          }, status: 500
        end
      end

      def avg_policy_value
        begin
          # Match the dashboard card: admin-added policies only (dr_filter)
          admin_scope = { is_admin_added: true, is_customer_added: false, is_agent_added: false }
          policy_data = []

        # Health Insurance
        begin
          health_policies = HealthInsurance.where(admin_scope)
          if health_policies.any?
            health_avg = health_policies.average(:net_premium) || 0
            policy_data << {
              type: 'Health Insurance',
              count: health_policies.count,
              total_premium: health_policies.sum(:net_premium) || 0,
              average: health_avg.to_f.round(2),
              min_premium: health_policies.minimum(:net_premium) || 0,
              max_premium: health_policies.maximum(:net_premium) || 0
            }
          end
        rescue => e
          Rails.logger.error "Error processing Health Insurance: #{e.message}"
        end

        # Life Insurance
        begin
          life_policies = LifeInsurance.where(admin_scope)
          if life_policies.any?
            life_avg = life_policies.average(:net_premium) || 0
            policy_data << {
              type: 'Life Insurance',
              count: life_policies.count,
              total_premium: life_policies.sum(:net_premium) || 0,
              average: life_avg.to_f.round(2),
              min_premium: life_policies.minimum(:net_premium) || 0,
              max_premium: life_policies.maximum(:net_premium) || 0
            }
          end
        rescue => e
          Rails.logger.error "Error processing Life Insurance: #{e.message}"
        end

        # Motor Insurance
        begin
          motor_policies = MotorInsurance.where(admin_scope)
          if motor_policies.any?
            motor_avg = motor_policies.average(:net_premium) || 0
            policy_data << {
              type: 'Motor Insurance',
              count: motor_policies.count,
              total_premium: motor_policies.sum(:net_premium) || 0,
              average: motor_avg.to_f.round(2),
              min_premium: motor_policies.minimum(:net_premium) || 0,
              max_premium: motor_policies.maximum(:net_premium) || 0
            }
          end
        rescue => e
          Rails.logger.error "Error processing Motor Insurance: #{e.message}"
        end

        # Other Insurance
        begin
          other_policies = OtherInsurance.where(admin_scope)
          if other_policies.any?
            other_avg = other_policies.average(:net_premium) || 0
            policy_data << {
              type: 'Other Insurance',
              count: other_policies.count,
              total_premium: other_policies.sum(:net_premium) || 0,
              average: other_avg.to_f.round(2),
              min_premium: other_policies.minimum(:net_premium) || 0,
              max_premium: other_policies.maximum(:net_premium) || 0
            }
          end
        rescue => e
          Rails.logger.error "Error processing Other Insurance: #{e.message}"
        end

        # Overall calculations — same formula as dashboard card: total_premium / total_policies
        total_policies = policy_data.sum { |p| p[:count] }
        total_premium = policy_data.sum { |p| p[:total_premium] }
        overall_avg = total_policies > 0 ? (total_premium.to_f / total_policies).round(2) : 0

        # Premium distribution ranges
        premium_ranges = [
          { range: 'Under Rs. 25,000', min: 0, max: 25000 },
          { range: 'Rs. 25,000 - Rs. 50,000', min: 25000, max: 50000 },
          { range: 'Rs. 50,000 - Rs. 1,00,000', min: 50000, max: 100000 },
          { range: 'Rs. 1,00,000 - Rs. 2,00,000', min: 100000, max: 200000 },
          { range: 'Above Rs. 2,00,000', min: 200000, max: Float::INFINITY }
        ]

        range_data = premium_ranges.map do |range|
          count = 0
          if range[:max] == Float::INFINITY
            count += HealthInsurance.where(admin_scope).where('net_premium >= ?', range[:min]).count rescue 0
            count += LifeInsurance.where(admin_scope).where('net_premium >= ?', range[:min]).count rescue 0
            count += MotorInsurance.where(admin_scope).where('net_premium >= ?', range[:min]).count rescue 0
            count += OtherInsurance.where(admin_scope).where('net_premium >= ?', range[:min]).count rescue 0
          else
            count += HealthInsurance.where(admin_scope).where(net_premium: range[:min]...range[:max]).count rescue 0
            count += LifeInsurance.where(admin_scope).where(net_premium: range[:min]...range[:max]).count rescue 0
            count += MotorInsurance.where(admin_scope).where(net_premium: range[:min]...range[:max]).count rescue 0
            count += OtherInsurance.where(admin_scope).where(net_premium: range[:min]...range[:max]).count rescue 0
          end

          {
            range: range[:range],
            count: count,
            percentage: total_policies > 0 ? ((count.to_f / total_policies) * 100).round(1) : 0
          }
        end

        render json: {
            success: true,
            calculation_method: "Overall Average = Total Premium ÷ Total Policies",
            summary: {
              overall_average: overall_avg.to_f,
              total_policies: total_policies,
              total_premium: total_premium.to_f
            },
            by_type: policy_data,
            distribution: range_data
          }
        rescue => e
          Rails.logger.error "Error in avg_policy_value: #{e.message}"
          Rails.logger.error e.backtrace.join("\n") if e.backtrace
          render json: {
            success: false,
            error: "Unable to load policy value data",
            calculation_method: "Overall Average = Total Premium ÷ Total Policies",
            summary: {
              overall_average: 0,
              total_policies: 0,
              total_premium: 0
            },
            by_type: [],
            distribution: []
          }, status: 500
        end
      end

      def commissions_due_detailed
        begin
          # Enhanced commission details with calculation breakdown
          pending_commissions = CommissionPayout.where(status: 'pending')
                                               .order(created_at: :desc)

          # Preload sub_agents for affiliate name lookup
          all_sub_agent_ids = []
          pending_commissions.each do |payout|
            pol = get_policy_for_payout(payout)
            all_sub_agent_ids << pol.try(:sub_agent_id) if pol
          end
          sub_agents_map = SubAgent.where(id: all_sub_agent_ids.compact.uniq)
                                   .index_by(&:id)

          # Batch-load Lead records keyed by display lead_id for DB-id lookup
          display_lead_ids = pending_commissions.map { |p| p.lead_id }.compact.uniq
          leads_map = Lead.where(lead_id: display_lead_ids).index_by(&:lead_id)

          commission_data = pending_commissions.map do |payout|
            policy = get_policy_for_payout(payout)
            percentage = payout.distribution_percentage || calculate_percentage_from_policy(policy, payout)

            customer_name = policy&.customer&.display_name || 'N/A'

            # Affiliate name from sub_agent linked to the policy
            affiliate_name = if policy&.try(:sub_agent_id)
                               sa = sub_agents_map[policy.sub_agent_id]
                               sa ? (sa.full_name.presence || "#{sa.first_name} #{sa.last_name}".strip.presence || "Affiliate ##{sa.id}") : 'N/A'
                             else
                               'N/A'
                             end

            premium_amount    = policy&.net_premium || policy&.total_premium || 0
            percentage_value  = (percentage || 0).to_f
            commission_amount = payout.payout_amount.round(2)

            # When the stored percentage is 0 but both premium and commission are known,
            # back-calculate the actual rate so the formula column is meaningful.
            if percentage_value == 0 && commission_amount > 0 && premium_amount > 0
              percentage_value = (commission_amount / premium_amount * 100).round(2)
            end

            formatted_premium    = ActionController::Base.helpers.number_to_currency(premium_amount,    unit: 'Rs. ', format: '%u%n', delimiter: ',', precision: 2)
            formatted_commission = ActionController::Base.helpers.number_to_currency(commission_amount, unit: 'Rs. ', format: '%u%n', delimiter: ',', precision: 2)

            calculation = if policy.nil?
                            "Fixed amount: #{formatted_commission} (policy not found)"
                          else
                            "#{formatted_premium} × #{percentage_value}% = #{formatted_commission}"
                          end

            display_lead_id = policy&.lead_id || payout.lead_id
            lead_record     = leads_map[display_lead_id]

            {
              id: payout.id,
              lead_id: display_lead_id || 'N/A',
              lead_db_id: lead_record&.id,
              policy_number: policy&.policy_number || 'N/A',
              policy_db_id: policy&.id,
              customer_name: customer_name,
              affiliate_name: affiliate_name,
              policy_type: payout.policy_type,
              payout_to: payout.payout_to,
              amount: commission_amount,
              percentage: percentage_value,
              base_premium: premium_amount,
              calculation: calculation,
              orphaned: policy.nil?,
              created_at: payout.created_at.strftime('%d %b %Y'),
              due_date: (payout.created_at + 30.days).strftime('%d %b %Y')
            }
          end

          # Summary by type (remove ordering for GROUP BY queries)
          type_summary = CommissionPayout.where(status: 'pending').group(:payout_to).sum(:payout_amount)

          # Summary by policy type
          policy_type_summary = CommissionPayout.where(status: 'pending').group(:policy_type).sum(:payout_amount)

          render json: {
            success: true,
            total_amount: CommissionPayout.where(status: 'pending').sum(:payout_amount),
            total_count: CommissionPayout.where(status: 'pending').count,
            data: commission_data,
            summary_by_recipient: type_summary,
            summary_by_policy_type: policy_type_summary,
            calculation_method: "Commission = Policy Premium × Commission Percentage"
          }
        rescue => e
          Rails.logger.error "Error in commissions_due_detailed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n") if e.backtrace
          render json: {
            success: false,
            error: "Unable to load commission data",
            total_amount: 0,
            total_count: 0,
            data: [],
            summary_by_recipient: {},
            summary_by_policy_type: {},
            calculation_method: "Commission = Policy Premium × Commission Percentage"
          }, status: 500
        end
      end

      def profit_summary
        start_date = params[:start_date].present? ? (Date.parse(params[:start_date]) rescue Date.current.beginning_of_year) : Date.current.beginning_of_year
        end_date   = params[:end_date].present?   ? (Date.parse(params[:end_date])   rescue Date.current.end_of_year)   : Date.current.end_of_year

        date_range = start_date..end_date

        policies = []

        [
          [HealthInsurance, 'Health'],
          [LifeInsurance,   'Life'],
          [MotorInsurance,  'Motor']
        ].each do |klass, label|
          begin
            klass.where(is_admin_added: true, is_customer_added: false, is_agent_added: false)
                 .where(policy_booking_date: date_range)
                 .includes(:customer)
                 .order(policy_booking_date: :desc)
                 .limit(200)
                 .each do |p|
              net       = p.net_premium.to_f
              main_pct  = p.try(:main_agent_commission_percentage).to_f
              main_amt  = p.try(:main_agent_commission_amount).to_f
              # Derive gross from percentage × premium when the stored amount is missing
              main_amt  = (net * main_pct / 100.0).round(2) if main_amt.zero? && main_pct > 0 && net > 0
              main_tds_pct = p.try(:main_agent_tds_percent).to_f.nonzero? || p.try(:tds_percentage).to_f
              main_tds_amt = p.try(:main_agent_tds_amount).to_f.nonzero? || (main_amt * main_tds_pct / 100.0).round(2)
              main_net  = p.try(:after_tds_value).to_f.nonzero? || (main_amt - main_tds_amt)

              aff_pct   = p.try(:sub_agent_commission_percentage).to_f
              aff_amt   = p.try(:sub_agent_commission_amount).to_f
              aff_amt   = (net * aff_pct / 100.0).round(2) if aff_amt.zero? && aff_pct > 0 && net > 0
              aff_tds_pct = p.try(:sub_agent_tds_percentage).to_f
              aff_tds_amt = p.try(:sub_agent_tds_amount).to_f
              aff_net   = p.try(:sub_agent_after_tds_value).to_f.nonzero? || (aff_amt - aff_tds_amt)

              amb_pct   = p.try(:ambassador_commission_percentage).to_f
              amb_amt   = p.try(:ambassador_commission_amount).to_f
              amb_amt   = (net * amb_pct / 100.0).round(2) if amb_amt.zero? && amb_pct > 0 && net > 0
              amb_tds_pct = p.try(:ambassador_tds_percentage).to_f
              amb_tds_amt = p.try(:ambassador_tds_amount).to_f
              amb_net   = p.try(:ambassador_after_tds_value).to_f.nonzero? || (amb_amt - amb_tds_amt)

              inv_pct   = p.try(:investor_commission_percentage).to_f
              inv_amt   = p.try(:investor_commission_amount).to_f
              inv_amt   = (net * inv_pct / 100.0).round(2) if inv_amt.zero? && inv_pct > 0 && net > 0
              inv_tds_pct = p.try(:investor_tds_percentage).to_f
              inv_tds_amt = p.try(:investor_tds_amount).to_f
              inv_net   = p.try(:investor_after_tds_value).to_f.nonzero? || (inv_amt - inv_tds_amt)

              co_pct    = p.try(:company_expenses_percentage).to_f
              co_amt    = net > 0 && co_pct > 0 ? (net * co_pct / 100.0).round(2) : 0.0

              # Always recalculate profit from live components — stored profit_amount
              # can be wrong when main_agent_commission_amount was saved as 0
              profit_amt = (main_amt - aff_amt - amb_amt - inv_amt - co_amt).round(2)
              profit_pct = net > 0 ? (profit_amt / net * 100).round(2) : 0

              total_dist_pct = p.try(:total_distribution_percentage).to_f

              policies << {
                policy_number:    p.try(:policy_number) || 'N/A',
                policy_type:      label,
                customer:         p.customer&.display_name || 'N/A',
                company:          p.try(:insurance_company_name) || 'N/A',
                booking_date:     p.try(:policy_booking_date)&.strftime('%d %b %Y') || p.created_at.strftime('%d %b %Y'),
                net_premium:      net.round(2),
                total_distribution_pct: total_dist_pct,
                company_expenses_pct:   co_pct,
                profit_amount:    profit_amt.round(2),
                profit_pct:       profit_pct.round(2),
                rows: [
                  { label: 'Main Agent',      pct: main_pct, amount: main_amt.round(2), tds_pct: main_tds_pct, tds_amt: main_tds_amt.round(2), actual: main_net.round(2) },
                  { label: 'Affiliate',       pct: aff_pct,  amount: aff_amt.round(2),  tds_pct: aff_tds_pct,  tds_amt: aff_tds_amt.round(2),  actual: aff_net.round(2) },
                  { label: 'Ambassador',      pct: amb_pct,  amount: amb_amt.round(2),  tds_pct: amb_tds_pct,  tds_amt: amb_tds_amt.round(2),  actual: amb_net.round(2) },
                  { label: 'Investor',        pct: inv_pct,  amount: inv_amt.round(2),  tds_pct: inv_tds_pct,  tds_amt: inv_tds_amt.round(2),  actual: inv_net.round(2) },
                  { label: 'Company Expense', pct: co_pct,   amount: co_amt.round(2),   tds_pct: nil,           tds_amt: nil,                   actual: co_amt.round(2) },
                  { label: 'Profit',          pct: profit_pct, amount: profit_amt.round(2), tds_pct: nil,       tds_amt: nil,                   actual: profit_amt.round(2) }
                ]
              }
            end
          rescue => e
            Rails.logger.error "profit_summary #{label}: #{e.message}"
          end
        end

        total_net_premium   = policies.sum { |p| p[:net_premium] }
        total_profit        = policies.sum { |p| p[:profit_amount] }
        total_main_agent    = policies.sum { |p| p[:rows][0][:actual] }
        avg_profit_pct      = policies.any? ? (policies.sum { |p| p[:profit_pct] } / policies.size).round(2) : 0

        render json: {
          success: true,
          start_date: start_date.strftime('%d %b %Y'),
          end_date:   end_date.strftime('%d %b %Y'),
          summary: {
            total_policies:   policies.size,
            total_net_premium: total_net_premium.round(2),
            total_profit:     total_profit.round(2),
            total_main_agent: total_main_agent.round(2),
            avg_profit_pct:   avg_profit_pct
          },
          policies: policies
        }
      rescue => e
        Rails.logger.error "Error in profit_summary: #{e.message}"
        render json: { success: false, error: e.message, policies: [], summary: {} }, status: 500
      end

      private

      def calculate_affiliate_policies(affiliate)
        count = 0
        count += HealthInsurance.where(sub_agent_id: affiliate.id).count rescue 0
        count += LifeInsurance.where(sub_agent_id: affiliate.id).count rescue 0
        count += MotorInsurance.where(sub_agent_id: affiliate.id).count rescue 0
        count
      end

      def calculate_affiliate_premium(affiliate)
        premium = 0
        premium += HealthInsurance.where(sub_agent_id: affiliate.id).sum(:total_premium) rescue 0
        premium += LifeInsurance.where(sub_agent_id: affiliate.id).sum(:total_premium) rescue 0
        premium += MotorInsurance.where(sub_agent_id: affiliate.id).sum(:total_premium) rescue 0
        premium
      end

      def calculate_affiliate_commission(affiliate, status)
        payout_to_values = ['sub_agent', 'affiliate']
        commission = 0
        commission += CommissionPayout.where(policy_type: 'health', payout_to: payout_to_values, status: status)
                                    .joins("JOIN health_insurances ON commission_payouts.policy_id = health_insurances.id")
                                    .where("health_insurances.sub_agent_id = ?", affiliate.id)
                                    .sum(:payout_amount) rescue 0
        commission += CommissionPayout.where(policy_type: 'life', payout_to: payout_to_values, status: status)
                                    .joins("JOIN life_insurances ON commission_payouts.policy_id = life_insurances.id")
                                    .where("life_insurances.sub_agent_id = ?", affiliate.id)
                                    .sum(:payout_amount) rescue 0
        commission += CommissionPayout.where(policy_type: 'motor', payout_to: payout_to_values, status: status)
                                    .joins("JOIN motor_insurances ON commission_payouts.policy_id = motor_insurances.id")
                                    .where("motor_insurances.sub_agent_id = ?", affiliate.id)
                                    .sum(:payout_amount) rescue 0
        commission += CommissionPayout.where(policy_type: 'other', payout_to: payout_to_values, status: status)
                                    .joins("JOIN other_insurances ON commission_payouts.policy_id = other_insurances.id")
                                    .where("other_insurances.sub_agent_id = ?", affiliate.id)
                                    .sum(:payout_amount) rescue 0
        commission
      end

      def get_policy_for_payout(payout)
        case payout.policy_type
        when 'health'
          HealthInsurance.find_by(id: payout.policy_id)
        when 'life'
          LifeInsurance.find_by(id: payout.policy_id)
        when 'motor'
          MotorInsurance.find_by(id: payout.policy_id)
        when 'other'
          OtherInsurance.find_by(id: payout.policy_id)
        else
          nil
        end
      end

      def calculate_percentage_from_policy(policy, payout)
        return 0 unless policy

        case payout.payout_to
        when 'sub_agent'
          policy.try(:sub_agent_commission_percentage) || 0
        when 'ambassador'
          policy.try(:ambassador_commission_percentage) || 0
        when 'investor'
          policy.try(:investor_commission_percentage) || 0
        when 'company_expense'
          policy.try(:company_expenses_percentage) || 0
        when 'main_agent'
          policy.try(:main_agent_commission_percentage) || 0
        else
          0
        end
      end
    end
  end
end