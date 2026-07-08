class Api::V1::PublicController < ActionController::Base
  # CORS headers for cross-origin requests
  before_action :set_cors_headers

  def search_sub_agents
    begin
      query = params[:q] || params[:query]
      customer_id = params[:customer_id]
      limit = params[:limit]&.to_i || 20
      affiliates = []

      Rails.logger.info "Public search sub agents called with query: '#{query}', customer_id: #{customer_id}, limit: #{limit}"

      # Start with truly active sub agents (active and not deactivated)
      sub_agents_scope = SubAgent.truly_active

      # If customer_id is provided, filter to show only the linked affiliate
      if customer_id.present?
        customer = Customer.find_by(id: customer_id)
        if customer&.affiliate
          # Customer has a linked affiliate, only show that one
          Rails.logger.info "Customer #{customer_id} is linked to affiliate #{customer.affiliate.id} (#{customer.affiliate.display_name})"

          if query.present? && query.strip.length >= 2
            # Apply search filter on the linked affiliate
            matching_affiliates = []

            # Always include Self option in search results
            if "self".include?(query.downcase) || "direct".include?(query.downcase)
              matching_affiliates << {
                id: '',
                text: 'Self',
                commission_earned: 0,
                customers_count: 0,
                policies_count: 0
              }
            end

            # Check if linked affiliate matches search
            if customer.affiliate.display_name.downcase.include?(query.downcase)
              matching_affiliates << {
                id: customer.affiliate.id,
                text: customer.affiliate.display_name,
                commission_earned: 0,
                customers_count: 0,
                policies_count: 0
              }
            end

            affiliates = matching_affiliates
          else
            # Just return Self and the linked affiliate
            affiliates = [
              {
                id: '',
                text: 'Self',
                commission_earned: 0,
                customers_count: 0,
                policies_count: 0
              },
              {
                id: customer.affiliate.id,
                text: customer.affiliate.display_name,
                commission_earned: 0,
                customers_count: 0,
                policies_count: 0
              }
            ]
          end

          Rails.logger.info "Filtered to customer's options (Self + linked affiliate): #{affiliates}"
          render json: { results: affiliates }
          return
        else
          Rails.logger.info "Customer #{customer_id} has no linked affiliate, showing all affiliates"
        end
      end

      # If no customer filter or customer has no linked affiliate, show all (original behavior)
      if query.present? && query.strip.length >= 2
        # Search with query
        matching_affiliates = []

        # Always include Self option in search results if it matches
        if "self".include?(query.downcase) || "direct".include?(query.downcase)
          matching_affiliates << {
            id: '',
            text: 'Self',
            commission_earned: 0,
            customers_count: 0,
            policies_count: 0
          }
        end

        # Add matching affiliates
        search_results = sub_agents_scope
                            .where("LOWER(first_name || ' ' || last_name) ILIKE ?", "%#{query.downcase}%")
                            .limit(limit - matching_affiliates.count) # Leave room for Self option
                            .map { |agent| {
                              id: agent.id,
                              text: agent.display_name,
                              commission_earned: 0,
                              customers_count: 0,
                              policies_count: 0
                            } }

        affiliates = matching_affiliates + search_results
        Rails.logger.info "Search found #{affiliates.count} total results (including Self if matched) for '#{query}'"
      else
        # Return default affiliates when no search query (Self + recently active affiliates)
        default_affiliates = sub_agents_scope
                            .order(:first_name, :last_name)
                            .limit([limit - 1, 10].min) # Reserve space for Self option
                            .map { |agent| {
                              id: agent.id,
                              text: agent.display_name,
                              commission_earned: 0,
                              customers_count: 0,
                              policies_count: 0
                            } }

        # Always include Self as first option
        affiliates = [{
          id: '',
          text: 'Self',
          commission_earned: 0,
          customers_count: 0,
          policies_count: 0
        }] + default_affiliates

        Rails.logger.info "Returning #{affiliates.count} default results (Self + #{default_affiliates.count} affiliates)"
      end

      Rails.logger.info "Returning sub agents: #{affiliates}"
      render json: { results: affiliates }
    rescue => e
      Rails.logger.error "Error in public search_sub_agents: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        results: [],
        error: "Failed to load affiliates: #{e.message}"
      }, status: 500
    end
  end

  def search_distributors
    begin
      query = params[:q] || params[:query]
      limit = params[:limit]&.to_i || 20
      distributors = []

      Rails.logger.info "Public search distributors called with query: '#{query}', limit: #{limit}"

      # Start with active distributors
      distributors_scope = Distributor.active

      if query.present? && query.strip.length >= 2
        # Search with query
        distributors = distributors_scope
                              .where("LOWER(first_name || ' ' || last_name) ILIKE ?", "%#{query.downcase}%")
                              .limit(limit)
                              .map { |distributor| {
                                id: distributor.id,
                                text: distributor.display_name,
                                commission_earned: 0,
                                customers_count: 0,
                                policies_count: 0
                              } }
        Rails.logger.info "Search found #{distributors.count} distributors matching '#{query}'"
      else
        # Return default distributors when no search query
        distributors = distributors_scope
                              .order(:first_name, :last_name)
                              .limit([limit, 10].min)
                              .map { |distributor| {
                                id: distributor.id,
                                text: distributor.display_name,
                                commission_earned: 0,
                                customers_count: 0,
                                policies_count: 0
                              } }
        Rails.logger.info "Returning #{distributors.count} default distributors"
      end

      Rails.logger.info "Returning distributors: #{distributors}"
      render json: { results: distributors }
    rescue => e
      Rails.logger.error "Error in public search_distributors: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        results: [],
        error: "Failed to load distributors: #{e.message}"
      }, status: 500
    end
  end

  def sub_agent_details
    begin
      sub_agent_id = params[:id]

      Rails.logger.info "Public sub_agent_details called with ID: #{sub_agent_id}"

      if sub_agent_id.blank?
        render json: {
          success: false,
          message: "Sub agent ID is required"
        }, status: 400
        return
      end

      sub_agent = SubAgent.find_by(id: sub_agent_id)

      if sub_agent.nil?
        render json: {
          success: false,
          message: "Sub agent not found"
        }, status: 404
        return
      end

      # Get distributor ID from the sub agent
      distributor_id = sub_agent.distributor_id || sub_agent.assigned_distributor&.id

      response_data = {
        success: true,
        sub_agent_id: sub_agent.id,
        sub_agent_name: sub_agent.display_name,
        distributor_id: distributor_id
      }

      if distributor_id
        distributor = Distributor.find_by(id: distributor_id)
        if distributor
          response_data[:distributor_name] = distributor.display_name
        end
      end

      Rails.logger.info "Returning sub agent details: #{response_data}"
      render json: response_data
    rescue => e
      Rails.logger.error "Error in public sub_agent_details: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        success: false,
        message: "Failed to load sub agent details: #{e.message}"
      }, status: 500
    end
  end

  # GET /api/v1/public/insurance_companies
  def insurance_companies
    begin
      page = params[:page] || 1
      per_page = params[:per_page] || 50
      search = params[:search]
      status_filter = params[:status] # 'active', 'inactive', or 'all'

      companies = InsuranceCompany.all

      # Apply search filter
      if search.present?
        companies = companies.where("name ILIKE ? OR code ILIKE ?", "%#{search}%", "%#{search}%")
      end

      # Apply status filter
      case status_filter
      when 'active'
        companies = companies.where(status: true)
      when 'inactive'
        companies = companies.where(status: false)
      # 'all' or nil shows all companies
      end

      companies = companies.order(:name)

      # Apply pagination if requested, otherwise return all
      if params[:page].present?
        companies = companies.page(page).per(per_page)
      end

      companies_data = companies.map do |company|
        {
          id: company.id,
          name: company.name,
          code: company.code,
          status: company.status ? 'Active' : 'Inactive',
          contact_person: company.contact_person,
          email: company.email,
          mobile: company.mobile,
          address: company.address,
          insurance_type: company.insurance_type
        }
      end

      render json: {
        success: true,
        data: companies_data,
        pagination: {
          current_page: params[:page]&.to_i || 1,
          per_page: per_page,
          total_companies: companies.respond_to?(:total_count) ? companies.total_count : companies_data.count,
          total_pages: companies.respond_to?(:total_pages) ? companies.total_pages : 1
        }
      }
    rescue => e
      Rails.logger.error "Error in public insurance_companies: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        success: false,
        message: "Failed to load insurance companies: #{e.message}"
      }, status: 500
    end
  end

  # GET /api/v1/public/motor_insurance_companies
  def motor_insurance_companies
    begin
      page = params[:page] || 1
      per_page = params[:per_page] || 50
      search = params[:search]

      companies = InsuranceCompany.where(status: true) # Only active companies for motor insurance

      # Apply search filter
      if search.present?
        companies = companies.where("name ILIKE ?", "%#{search}%")
      end

      companies = companies.order(:name)

      # Apply pagination if requested, otherwise return all
      if params[:page].present?
        companies = companies.page(page).per(per_page)
      end

      companies_data = companies.map do |company|
        {
          id: company.id,
          name: company.name,
          code: company.code,
          contact_person: company.contact_person,
          email: company.email,
          mobile: company.mobile
        }
      end

      render json: {
        success: true,
        data: companies_data,
        pagination: {
          current_page: params[:page]&.to_i || 1,
          per_page: per_page,
          total_companies: companies.respond_to?(:total_count) ? companies.total_count : companies_data.count,
          total_pages: companies.respond_to?(:total_pages) ? companies.total_pages : 1
        }
      }
    rescue => e
      Rails.logger.error "Error in public motor_insurance_companies: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        success: false,
        message: "Failed to load motor insurance companies: #{e.message}"
      }, status: 500
    end
  end

  private

  def set_cors_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Content-Type, Accept'
  end
end