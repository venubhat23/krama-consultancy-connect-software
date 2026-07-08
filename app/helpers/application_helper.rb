module ApplicationHelper
  include CurrencyHelper

  # Customer avatar helpers
  def customer_initials(customer)
    if customer.customer_type == 'corporate' && customer.company_name.present?
      customer.company_name.split.map(&:first).join.upcase[0, 2]
    elsif customer.display_name.present?
      customer.display_name.split.map(&:first).join.upcase[0, 2]
    else
      'CU'
    end
  end

  def customer_avatar_color(customer)
    colors = [
      '#6f42c1', # Purple
      '#20c997', # Teal
      '#fd7e14', # Orange
      '#e91e63', # Pink
      '#00bcd4', # Cyan
      '#795548', # Brown
      '#607d8b', # Blue Grey
      '#ff5722', # Deep Orange
      '#9c27b0', # Purple
      '#00e676'  # Green
    ]

    # Use customer ID to consistently assign same color
    color_index = customer.id % colors.length
    colors[color_index]
  end

  # Permission checking helpers
  def current_user_can?(module_name, action = 'read')
    return true if current_user&.admin? || current_user&.user_type == 'admin'
    return current_user.has_permission?(module_name, action) if current_user&.role
    false
  end

  def show_sidebar_item?(module_name, action = 'read')
    return false unless current_user
    return true if sidebar_full_access?
    current_user.has_sidebar_permission?(module_name)
  end

  # Helper method to check if any items in a section are visible
  def show_sidebar_section?(section_items)
    return false unless current_user
    return true if sidebar_full_access?
    section_items.any? { |item| current_user.has_sidebar_permission?(item) }
  end

  private

  def sidebar_full_access?
    return true if current_user.email == 'admin@drwise.com'
    # Admin users with no specific role assigned get full sidebar access
    current_user.user_type == 'admin' && current_user.role_name.blank?
  end

  public

  def sidebar_item_class(current_path, module_paths = [])
    paths_to_check = [current_path] + module_paths
    paths_to_check.any? { |path| request.path.include?(path) } ? 'active' : ''
  end

  # Forum-platform role label/color for the sidebar profile card.
  FORUM_ROLE_LABELS = {
    'forum_admin' => 'Forum Admin',
    'chapter_admin' => 'Chapter Admin',
    'member' => 'Member'
  }.freeze

  FORUM_ROLE_BADGE_CLASSES = {
    'forum_admin' => 'bg-primary',
    'chapter_admin' => 'bg-info',
    'member' => 'bg-success'
  }.freeze

  def sidebar_role_label(user)
    return 'Super Admin' if user.super_admin?
    FORUM_ROLE_LABELS[user.user_type] || user.role_display_name
  end

  def sidebar_role_badge_class(user)
    return 'bg-danger' if user.super_admin?
    FORUM_ROLE_BADGE_CLASSES[user.user_type] || 'bg-secondary'
  end

  # Role and permission helpers
  def user_role_badge(user)
    return content_tag(:span, 'No Role', class: 'badge bg-secondary') unless user&.role

    role_colors = {
      'admin' => 'bg-danger',
      'manager' => 'bg-primary',
      'agent' => 'bg-success',
      'supervisor' => 'bg-warning',
      'sub_agent' => 'bg-info'
    }

    color_class = role_colors[user.role.name.downcase] || 'bg-secondary'
    content_tag(:span, user.role.display_name, class: "badge #{color_class}")
  end

  def permission_icon(action_type)
    icons = {
      'create' => 'bi-plus-circle',
      'read' => 'bi-eye',
      'update' => 'bi-pencil',
      'delete' => 'bi-trash',
      'export' => 'bi-download',
      'import' => 'bi-upload',
      'manage' => 'bi-gear'
    }

    content_tag(:i, '', class: "bi #{icons[action_type] || 'bi-circle'}")
  end

  def module_icon(module_name)
    icons = {
      'dashboard' => 'bi-grid-3x3-gap-fill',
      'customers' => 'bi-people-fill',
      'helpdesk' => 'bi-headset',
      'users' => 'bi-person-badge-fill',
      'sub_agents' => 'bi-people',
      'brokers' => 'bi-briefcase',
      'agency_codes' => 'bi-code-slash',
      'leads' => 'bi-funnel-fill',
      'life_insurance' => 'bi-heart-fill',
      'health_insurance' => 'bi-hospital',
      'motor_insurance' => 'bi-car-front',
      'other_insurance' => 'bi-shield-fill-check',
      'payouts' => 'bi-cash-coin',
      'reports' => 'bi-graph-up',
      'settings' => 'bi-gear-fill',
      'roles' => 'bi-shield-check'
    }

    content_tag(:i, '', class: "bi #{icons[module_name] || 'bi-circle'}")
  end

  def get_module_icon(module_name)
    icons = {
      'dashboard' => 'bi-grid-3x3-gap-fill',
      'customers' => 'bi-people-fill',
      'policies' => 'bi-file-earmark-text-fill',
      'agents' => 'bi-person-badge-fill',
      'sub_agents' => 'bi-people',
      'brokers' => 'bi-briefcase',
      'agency_codes' => 'bi-code-slash',
      'leads' => 'bi-funnel-fill',
      'life_insurance' => 'bi-heart-fill',
      'health_insurance' => 'bi-hospital-fill',
      'motor_insurance' => 'bi-car-front-fill',
      'other_insurance' => 'bi-shield-fill-check',
      'reports' => 'bi-graph-up',
      'management' => 'bi-building-fill',
      'settings' => 'bi-gear-fill'
    }

    content_tag(:i, '', class: "bi #{icons[module_name] || 'bi-circle'}")
  end

  # Status helpers
  def status_badge(status, active_text = 'Active', inactive_text = 'Inactive')
    if status
      content_tag(:span, active_text, class: 'badge bg-success-soft text-success')
    else
      content_tag(:span, inactive_text, class: 'badge bg-danger-soft text-danger')
    end
  end

  # Form helpers
  def form_errors_for(object)
    return unless object&.errors&.any?

    content_tag(:div, class: 'alert alert-danger alert-dismissible fade show') do
      content_tag(:h6, 'Please correct the following errors:') +
      content_tag(:ul, class: 'mb-0') do
        object.errors.full_messages.map do |message|
          content_tag(:li, message)
        end.join.html_safe
      end +
      content_tag(:button, '', type: 'button', class: 'btn-close', 'data-bs-dismiss': 'alert')
    end
  end

  # Payout form helpers
  def policy_options_for_select(policy_type = nil)
    policies = []

    case policy_type
    when 'health_insurance', 'health'
      policies = HealthInsurance.includes(:customer)
                                .select(:id, :policy_number, :customer_id, :total_premium)
                                .map do |policy|
        customer_name = policy.customer&.display_name || 'Unknown Customer'
        ["#{policy.policy_number || "Policy ##{policy.id}"} - #{customer_name} - #{indian_currency(policy.total_premium)}", policy.id]
      end
    when 'life_insurance', 'life'
      policies = LifeInsurance.includes(:customer)
                              .select(:id, :policy_number, :customer_id, :total_premium)
                              .map do |policy|
        customer_name = policy.customer&.display_name || 'Unknown Customer'
        premium = policy.total_premium || 0
        ["#{policy.policy_number || "Policy ##{policy.id}"} - #{customer_name} - #{indian_currency(premium)}", policy.id]
      end
    when 'motor_insurance', 'motor'
      if defined?(MotorInsurance)
        policies = MotorInsurance.includes(:customer)
                                 .select(:id, :policy_number, :customer_id, :total_premium)
                                 .map do |policy|
          customer_name = policy.customer&.display_name || 'Unknown Customer'
          premium = policy.total_premium || 0
          ["#{policy.policy_number || "Policy ##{policy.id}"} - #{customer_name} - #{indian_currency(premium)}", policy.id]
        end
      end
    when 'general_insurance', 'general'
      if defined?(GeneralInsurance)
        policies = GeneralInsurance.includes(:customer)
                                   .select(:id, :policy_number, :customer_id, :total_premium)
                                   .map do |policy|
          customer_name = policy.customer&.display_name || 'Unknown Customer'
          premium = policy.total_premium || 0
          ["#{policy.policy_number || "Policy ##{policy.id}"} - #{customer_name} - #{indian_currency(premium)}", policy.id]
        end
      end
    else
      # Return all policies if no type specified
      health_policies = HealthInsurance.includes(:customer)
                                       .select(:id, :policy_number, :customer_id, :total_premium)
                                       .map do |policy|
        customer_name = policy.customer&.display_name || 'Unknown Customer'
        ["Health: #{policy.policy_number || "Policy ##{policy.id}"} - #{customer_name} - #{indian_currency(policy.total_premium)}", policy.id]
      end

      life_policies = LifeInsurance.includes(:customer)
                                   .select(:id, :policy_number, :customer_id, :total_premium)
                                   .map do |policy|
        customer_name = policy.customer&.display_name || 'Unknown Customer'
        premium = policy.total_premium || 0
        ["Life: #{policy.policy_number || "Policy ##{policy.id}"} - #{customer_name} - #{indian_currency(premium)}", policy.id]
      end

      policies = health_policies + life_policies
    end

    policies
  rescue => e
    Rails.logger.error "Error fetching policy options: #{e.message}"
    []
  end

  # Commission flow visualization helpers
  def commission_flow_status_icon(status)
    icons = {
      'paid' => 'bi-check-circle text-success',
      'pending' => 'bi-clock text-warning',
      'processing' => 'bi-arrow-repeat text-info',
      'failed' => 'bi-x-circle text-danger',
      'cancelled' => 'bi-x-circle text-danger'
    }
    content_tag(:i, '', class: "bi #{icons[status] || 'bi-circle text-muted'}")
  end

  def commission_flow_status_badge(status)
    badges = {
      'paid' => 'badge bg-success',
      'pending' => 'badge bg-warning',
      'processing' => 'badge bg-info',
      'failed' => 'badge bg-danger',
      'cancelled' => 'badge bg-secondary'
    }
    content_tag(:span, status.humanize, class: badges[status] || 'badge bg-secondary')
  end

  def policy_commission_breakdown(policy)
    breakdown = {}
    return breakdown unless policy

    if policy.respond_to?(:sub_agent_after_tds_value)
      breakdown[:sub_agent] = {
        amount: policy.sub_agent_after_tds_value || 0,
        percentage: policy.respond_to?(:sub_agent_commission_percentage) ? policy.sub_agent_commission_percentage : 0
      }
    end

    if policy.respond_to?(:distributor_after_tds_value)
      breakdown[:distributor] = {
        amount: policy.distributor_after_tds_value || 0,
        percentage: policy.respond_to?(:distributor_commission_percentage) ? policy.distributor_commission_percentage : 0
      }
    end

    if policy.respond_to?(:investor_after_tds_value)
      breakdown[:investor] = {
        amount: policy.investor_after_tds_value || 0,
        percentage: policy.respond_to?(:investor_commission_percentage) ? policy.investor_commission_percentage : 0
      }
    end

    if policy.respond_to?(:commission_amount)
      breakdown[:main_agent] = {
        amount: policy.commission_amount || 0,
        percentage: policy.respond_to?(:main_agent_commission_percentage) ? policy.main_agent_commission_percentage : 0
      }
    end

    if policy.respond_to?(:company_expenses_percentage)
      total_premium = policy.total_premium || policy.net_premium || 0
      breakdown[:company] = {
        amount: (total_premium * policy.company_expenses_percentage / 100).to_f,
        percentage: policy.company_expenses_percentage || 0
      }
    end

    breakdown
  end

  def total_commission_flow(policy)
    breakdown = policy_commission_breakdown(policy)
    breakdown.values.sum { |item| item[:amount] }
  end

  def commission_flow_timeline_data(policy_id, policy_type)
    case policy_type
    when 'health'
      policy = HealthInsurance.find_by(id: policy_id)
    when 'life'
      policy = LifeInsurance.find_by(id: policy_id)
    else
      return []
    end

    return [] unless policy

    timeline = []
    breakdown = policy_commission_breakdown(policy)
    payouts = CommissionPayout.where(policy_id: policy_id, policy_type: policy_type)

    breakdown.each do |recipient, data|
      payout = payouts.find { |p| p.payout_to.include?(recipient.to_s) }

      timeline << {
        recipient: recipient.to_s.humanize,
        amount: data[:amount],
        percentage: data[:percentage],
        status: payout&.status || 'not_initiated',
        date: payout&.payout_date,
        reference: payout&.reference_number,
        notes: payout&.notes
      }
    end

    timeline.sort_by { |item| item[:amount] }.reverse
  end

  def format_currency(amount)
    indian_currency(amount)
  end

  def percentage_display(percentage)
    return '-' if percentage.nil? || percentage == 0
    "#{percentage}%"
  end

  def commission_health_indicator(paid_count, total_count)
    return 'text-muted' if total_count == 0

    percentage = (paid_count.to_f / total_count * 100)

    case percentage
    when 100
      'text-success'
    when 50..99
      'text-warning'
    when 1..49
      'text-danger'
    else
      'text-muted'
    end
  end

  def days_since_policy_created(policy)
    return 0 unless policy&.created_at
    (Date.current - policy.created_at.to_date).to_i
  end

  def sla_status(days)
    case days
    when 0..3
      { class: 'text-success', text: 'On Time' }
    when 4..7
      { class: 'text-warning', text: 'Due Soon' }
    else
      { class: 'text-danger', text: 'Overdue' }
    end
  end

  # Timeline helpers for audit trail and flow timeline
  def timeline_icon_for_action(action)
    case action.to_s
    when 'created' then 'bi-plus-circle'
    when 'updated' then 'bi-pencil-square'
    when 'marked_paid' then 'bi-check-circle'
    when 'processing' then 'bi-clock'
    when 'cancelled' then 'bi-x-circle'
    when 'deleted' then 'bi-trash'
    else 'bi-circle'
    end
  end

  def timeline_color_for_action(action)
    case action.to_s
    when 'created' then 'primary'
    when 'updated' then 'info'
    when 'marked_paid' then 'success'
    when 'processing' then 'warning'
    when 'cancelled' then 'danger'
    when 'deleted' then 'danger'
    else 'secondary'
    end
  end

  # Pagination helper methods
  def should_show_pagination?(records = nil)
    return @show_pagination if @show_pagination.present?

    if records
      total = records.respond_to?(:total_count) ? records.total_count : records.count
      per_page = @items_per_page || SystemSetting.default_pagination_per_page
      total > per_page
    else
      false
    end
  end

  # Lead stage helper methods
  def get_stage_display_name(stage)
    case stage.to_s
    when 'new' then 'New Lead'
    when 'contacted' then 'Contacted'
    when 'qualified' then 'Qualified'
    when 'proposal' then 'Proposal'
    when 'negotiation' then 'Negotiation'
    when 'closed_won' then 'Closed Won'
    when 'closed_lost' then 'Closed Lost'
    when 'follow_up' then 'Follow Up'
    when 'not_interested' then 'Not Interested'
    else stage.to_s.humanize
    end
  end

  def get_stage_button_class(stage)
    case stage.to_s
    when 'new' then 'btn-outline-primary'
    when 'contacted' then 'btn-outline-info'
    when 'qualified' then 'btn-outline-warning'
    when 'proposal' then 'btn-outline-secondary'
    when 'negotiation' then 'btn-outline-dark'
    when 'closed_won' then 'btn-outline-success'
    when 'closed_lost' then 'btn-outline-danger'
    when 'follow_up' then 'btn-outline-warning'
    when 'not_interested' then 'btn-outline-secondary'
    else 'btn-outline-secondary'
    end
  end

  # Terminology mapping helpers for new naming convention
  def display_term(old_term)
    terminology_map = {
      'Sub Agent' => 'Affiliate',
      'sub_agent' => 'affiliate',
      'SubAgent' => 'Affiliate',
      'sub_agents' => 'affiliates',
      'Sub Agents' => 'Affiliates',
      'Distributor' => 'Ambassador',
      'distributor' => 'ambassador',
      'distributors' => 'ambassadors',
      'Distributors' => 'Ambassadors'
    }
    terminology_map[old_term] || old_term
  end

  def human_readable_model_name(model_name)
    case model_name.to_s.downcase
    when 'subagent', 'sub_agent'
      'Affiliate'
    when 'distributor'
      'Ambassador'
    else
      model_name.to_s.humanize
    end
  end

  # Sub Agent performance optimization helpers
  def total_policy_count_for_sub_agent(sub_agent_id, health_counts, life_counts, motor_counts)
    (health_counts[sub_agent_id] || 0) +
    (life_counts[sub_agent_id] || 0) +
    (motor_counts[sub_agent_id] || 0)
  end
end
