class Admin::AiReportsController < Admin::ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: [:generate, :ask, :history]

  # GET /admin/ai_reports/chat_interface
  def chat_interface
    @available_reports = %w[commission expired_insurance payment_due upcoming_renewal leads sessions]
    @recent_reports = AiReportHistory.where(user: current_user).recent.limit(5) if defined?(AiReportHistory)
  end

  # POST /admin/ai_reports/generate
  def generate
    @report_type = params[:report_type]
    @filters = filter_params

    # Validate inputs
    unless valid_report_type?(@report_type)
      render json: { error: "Invalid report type" }, status: 400
      return
    end

    # Generate AI Report using mock service for now
    begin
      @ai_report = generate_mock_ai_report(@report_type, @filters)

      # Save report for history if model exists
      save_report_to_history(@ai_report) if defined?(AiReportHistory)

      render json: { success: true, report: @ai_report }
    rescue => e
      Rails.logger.error "AI Report Generation Error: #{e.message}"
      render json: { error: "Failed to generate report: #{e.message}" }, status: 500
    end
  end

  # POST /admin/ai_reports/ask
  def ask
    question = params[:question]
    context = params[:context] || {}

    # Mock AI response for now
    ai_response = generate_mock_ai_response(question, context)

    render json: {
      success: true,
      response: ai_response[:message],
      suggested_actions: ai_response[:actions],
      confidence: ai_response[:confidence]
    }
  end

  # GET /admin/ai_reports/history
  def history
    if defined?(AiReportHistory)
      @reports = AiReportHistory.where(user: current_user).recent.limit(20)
    else
      @reports = []
    end

    render json: { reports: @reports }
  end

  private

  def filter_params
    params.permit(:date_range, :agent_id, :insurance_type, :customer_id,
                  :policy_type, :status, :priority, :risk_level)
  end

  def valid_report_type?(type)
    %w[commission expired_insurance payment_due upcoming_renewal leads sessions].include?(type)
  end

  def generate_mock_ai_report(report_type, filters)
    case report_type
    when 'commission'
      generate_commission_ai_report(filters)
    when 'expired_insurance'
      generate_expired_insurance_ai_report(filters)
    when 'payment_due'
      generate_payment_due_ai_report(filters)
    when 'upcoming_renewal'
      generate_renewal_ai_report(filters)
    when 'leads'
      generate_leads_ai_report(filters)
    when 'sessions'
      generate_sessions_ai_report(filters)
    else
      { error: "Unknown report type" }
    end
  end

  def generate_commission_ai_report(filters)
    # Get actual data from your models
    date_range = parse_date_range(filters[:date_range] || '30_days')

    total_commission = calculate_total_commission(date_range)
    agent_commissions = calculate_agent_commissions(date_range)

    {
      report_type: 'AI Commission Intelligence Report',
      generated_at: Time.current,
      filters_applied: filters,
      data: {
        total_commission: total_commission,
        agent_commissions: agent_commissions,
        average_commission: agent_commissions.any? ? total_commission / agent_commissions.count : 0,
        period: filters[:date_range] || '30_days'
      },
      ai_analysis: {
        summary: generate_commission_summary(total_commission, agent_commissions),
        insights: generate_commission_insights(agent_commissions),
        predictions: generate_commission_predictions(agent_commissions),
        recommendations: generate_commission_recommendations(agent_commissions),
        anomalies: detect_commission_anomalies(agent_commissions)
      },
      confidence_score: calculate_confidence_score(agent_commissions),
      next_suggested_actions: generate_action_items(agent_commissions)
    }
  end

  def generate_expired_insurance_ai_report(filters)
    # Get expired policies
    expired_health = HealthInsurance.where('policy_end_date < ?', Date.current).limit(50)
    expired_life = LifeInsurance.where('policy_end_date < ?', Date.current).limit(50)

    total_expired = expired_health.count + expired_life.count

    {
      report_type: 'AI Expired Insurance Intelligence Report',
      generated_at: Time.current,
      filters_applied: filters,
      data: {
        total_expired: total_expired,
        health_expired: expired_health.count,
        life_expired: expired_life.count,
        expired_policies: (expired_health.to_a + expired_life.to_a).first(20)
      },
      ai_analysis: {
        summary: "Found #{total_expired} expired policies requiring attention",
        insights: [
          {
            type: 'renewal_opportunity',
            insight: "#{(total_expired * 0.4).round} policies have high renewal probability",
            impact: 'high',
            recommendation: 'Priority follow-up within 7 days'
          }
        ],
        predictions: {
          renewal_probability: "45% average renewal rate expected",
          revenue_potential: "#{format_currency(total_expired * 25000)} potential revenue"
        },
        recommendations: generate_renewal_recommendations(total_expired)
      },
      confidence_score: 78,
      next_suggested_actions: [
        { priority: 'high', action: 'Contact high-probability customers', count: (total_expired * 0.4).round },
        { priority: 'medium', action: 'Send renewal reminders', count: total_expired }
      ]
    }
  end

  def generate_mock_ai_response(question, context)
    # Mock intelligent responses based on question
    case question.downcase
    when /commission/
      {
        message: "Based on your commission data, I can see trends showing growth in life insurance commissions. Would you like me to generate a detailed commission report with predictions?",
        actions: [
          { type: 'generate_report', data: 'commission', label: 'Generate Commission Report' },
          { type: 'show_trends', data: 'commission_trends', label: 'Show Trends' }
        ],
        confidence: 85
      }
    when /expired/
      {
        message: "I found several expired policies that need attention. Let me analyze renewal opportunities for you.",
        actions: [
          { type: 'generate_report', data: 'expired_insurance', label: 'Analyze Expired Policies' },
          { type: 'show_renewal_opportunities', data: 'renewals', label: 'Show Opportunities' }
        ],
        confidence: 90
      }
    when /predict/
      {
        message: "I can predict future revenue based on current trends. Your business is showing positive growth patterns.",
        actions: [
          { type: 'show_predictions', data: 'revenue_forecast', label: 'Show Forecast' },
          { type: 'generate_report', data: 'leads', label: 'Analyze Lead Pipeline' }
        ],
        confidence: 75
      }
    else
      {
        message: "I can help you analyze your insurance business data. Try asking about commissions, expired policies, or revenue predictions.",
        actions: [
          { type: 'generate_report', data: 'commission', label: 'Commission Analysis' },
          { type: 'generate_report', data: 'expired_insurance', label: 'Policy Analysis' }
        ],
        confidence: 60
      }
    end
  end

  def calculate_total_commission(date_range)
    life_commission = LifeInsurance.where(created_at: date_range).sum(:commission_amount) || 0
    health_commission = HealthInsurance.where(created_at: date_range).sum(:commission_amount) || 0
    life_commission + health_commission
  end

  def calculate_agent_commissions(date_range)
    # Combine commissions from both insurance types
    agent_data = {}

    LifeInsurance.joins(:sub_agent)
                 .where(created_at: date_range)
                 .group('sub_agents.first_name', 'sub_agents.last_name', 'sub_agents.id')
                 .sum(:commission_amount)
                 .each do |key, commission|
      agent_name = "#{key[0]} #{key[1]}"
      agent_data[agent_name] = (agent_data[agent_name] || 0) + commission
    end

    HealthInsurance.joins(:sub_agent)
                   .where(created_at: date_range)
                   .group('sub_agents.first_name', 'sub_agents.last_name', 'sub_agents.id')
                   .sum(:commission_amount)
                   .each do |key, commission|
      agent_name = "#{key[0]} #{key[1]}"
      agent_data[agent_name] = (agent_data[agent_name] || 0) + commission
    end

    agent_data.map { |name, commission| { agent_name: name, commission: commission } }
           .sort_by { |agent| -agent[:commission] }
  rescue => e
    Rails.logger.error "Error calculating agent commissions: #{e.message}"
    []
  end

  def generate_commission_summary(total, agents)
    if agents.any?
      "Generated Rs. #{format_currency(total)} in total commissions across #{agents.count} agents. Top performer earned Rs. #{format_currency(agents.first[:commission])}."
    else
      "No commission data available for the selected period."
    end
  end

  def generate_commission_insights(agents)
    insights = []

    if agents.any?
      top_performer = agents.first
      avg_commission = agents.sum { |a| a[:commission] } / agents.count

      insights << {
        type: 'top_performer',
        insight: "#{top_performer[:agent_name]} is the top performer with Rs. #{format_currency(top_performer[:commission])}",
        impact: 'high',
        recommendation: 'Consider rewarding and learning from their strategies'
      }

      underperformers = agents.select { |a| a[:commission] < avg_commission * 0.5 }
      if underperformers.any?
        insights << {
          type: 'underperformance',
          insight: "#{underperformers.count} agents are performing below 50% of average",
          impact: 'medium',
          recommendation: 'Provide additional training and support'
        }
      end
    end

    insights
  end

  def generate_commission_predictions(agents)
    return {} if agents.empty?

    current_total = agents.sum { |a| a[:commission] }
    growth_rate = 0.15 # Mock 15% growth rate

    {
      next_month: {
        predicted_amount: current_total * (1 + growth_rate),
        confidence: 82
      },
      growth_trend: growth_rate > 0 ? 'increasing' : 'stable',
      factors: ['Strong market demand', 'Experienced agent team', 'Seasonal uptick']
    }
  end

  def generate_commission_recommendations(agents)
    recommendations = []

    if agents.any?
      recommendations << {
        priority: 'high',
        category: 'performance',
        title: 'Agent Performance Optimization',
        description: 'Focus on training underperforming agents',
        potential_impact: '20-30% commission increase'
      }

      recommendations << {
        priority: 'medium',
        category: 'retention',
        title: 'Top Performer Retention',
        description: 'Implement retention strategies for high performers',
        potential_impact: 'Prevent revenue loss'
      }
    end

    recommendations
  end

  def detect_commission_anomalies(agents)
    return [] if agents.empty?

    avg_commission = agents.sum { |a| a[:commission] } / agents.count
    anomalies = []

    agents.each do |agent|
      if agent[:commission] > avg_commission * 3
        anomalies << {
          type: 'high_performance',
          agent: agent[:agent_name],
          description: 'Exceptionally high commission - investigate for best practices',
          severity: 'info'
        }
      elsif agent[:commission] < avg_commission * 0.2
        anomalies << {
          type: 'low_performance',
          agent: agent[:agent_name],
          description: 'Very low commission - requires immediate attention',
          severity: 'warning'
        }
      end
    end

    anomalies
  end

  def calculate_confidence_score(data)
    return 50 if data.empty?

    base_score = 70
    data_quality_bonus = data.count > 5 ? 15 : data.count * 2
    [base_score + data_quality_bonus, 95].min
  end

  def generate_action_items(agents)
    items = []

    if agents.any?
      items << {
        priority: 'high',
        action: 'Review top performer strategies',
        timeline: '1 week'
      }

      underperformers = agents.select { |a| a[:commission] < 1000 }
      if underperformers.any?
        items << {
          priority: 'high',
          action: "Provide training to #{underperformers.count} underperforming agents",
          timeline: '2 weeks'
        }
      end
    end

    items
  end

  def generate_renewal_recommendations(count)
    [
      {
        priority: 'high',
        category: 'immediate',
        title: 'High-Priority Follow-ups',
        description: "Contact #{(count * 0.3).round} customers with highest renewal probability"
      },
      {
        priority: 'medium',
        category: 'automation',
        title: 'Automated Renewal Campaign',
        description: 'Set up email/SMS campaign for all expired policies'
      }
    ]
  end

  def parse_date_range(range)
    case range
    when '7_days'
      7.days.ago..Time.current
    when '30_days'
      30.days.ago..Time.current
    when '3_months'
      3.months.ago..Time.current
    when '6_months'
      6.months.ago..Time.current
    when '1_year'
      1.year.ago..Time.current
    else
      30.days.ago..Time.current
    end
  end

  def format_currency(amount)
    return "Rs. 0.00" if amount.nil? || amount.zero?
    amount = amount.to_f
    integer_part = amount.to_i.to_s
    decimal_part = sprintf("%.2f", amount).split('.').last
    reversed = integer_part.reverse
    result = []
    reversed.chars.each_with_index do |char, index|
      result << char
      if index == 2 && reversed.length > 3
        result << ','
      elsif index > 2 && (index - 2) % 2 == 0 && index < reversed.length - 1
        result << ','
      end
    end
    "Rs. #{result.reverse.join}.#{decimal_part}"
  end

  def save_report_to_history(report)
    return unless defined?(AiReportHistory)

    AiReportHistory.create!(
      user: current_user,
      report_type: @report_type,
      filters: @filters,
      ai_insights: report[:ai_analysis],
      confidence_score: report[:confidence_score],
      generated_at: Time.current
    )
  rescue => e
    Rails.logger.error "Failed to save AI report history: #{e.message}"
  end
end