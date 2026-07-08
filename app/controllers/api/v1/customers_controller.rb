class Api::V1::CustomersController < Api::V1::ApplicationController
  before_action :set_customer, only: [:show, :update, :destroy]

  # GET /api/v1/customers
  def index
    @customers = Customer.includes(:family_members, :corporate_members, :documents)

    # Search functionality
    if params[:search].present?
      @customers = @customers.search_customers(params[:search])
    end

    # Filter by customer type
    if params[:customer_type].present?
      @customers = @customers.where(customer_type: params[:customer_type])
    end

    # Filter by status
    case params[:status]
    when 'active'
      @customers = @customers.active
    when 'inactive'
      @customers = @customers.inactive
    end

    @customers = @customers.order(created_at: :desc)
                          .limit(params[:limit] || 50)
                          .offset(params[:offset] || 0)

    render_success(
      customers: @customers.map { |customer| customer_summary(customer) },
      total_count: Customer.count,
      message: 'Customers retrieved successfully'
    )
  end

  # GET /api/v1/customers/:id
  def show
    render_success(
      customer: customer_details(@customer),
      message: 'Customer retrieved successfully'
    )
  end

  # POST /api/v1/customers
  def create
    @customer = Customer.new(customer_params)

    if @customer.save
      render_success(
        {
          customer: customer_details(@customer),
          message: 'Customer created successfully'
        },
        :created
      )
    else
      render_validation_errors(@customer)
    end
  end

  # POST /api/v1/customers/register
  # Accepts flat JSON structure for customer registration
  def register
    @customer = Customer.new(flat_customer_params)

    if @customer.save
      render json: {
        status: true,
        message: 'Customer created successfully',
        data: {
          id: @customer.id,
          customer_type: @customer.customer_type,
          display_name: @customer.display_name,
          email: @customer.email,
          mobile: @customer.mobile
        }
      }, status: :created
    else
      render json: {
        status: false,
        message: 'Failed to create customer',
        errors: @customer.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/customers/:id
  def update
    if @customer.update(customer_params)
      render_success(
        customer: customer_details(@customer),
        message: 'Customer updated successfully'
      )
    else
      render_validation_errors(@customer)
    end
  end

  # DELETE /api/v1/customers/:id
  def destroy
    if @customer.policies.exists?
      render_error('Cannot delete customer with existing policies', nil, :forbidden)
    else
      @customer.destroy
      render_success(nil, 'Customer deleted successfully')
    end
  end

  # PATCH /api/v1/customers/:id/toggle_status
  def toggle_status
    @customer.update(status: !@customer.status)
    status_text = @customer.status? ? 'activated' : 'deactivated'

    render_success(
      customer: customer_summary(@customer),
      message: "Customer #{status_text} successfully"
    )
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Customer not found', nil, :not_found)
  end

  def customer_params
    params.require(:customer).permit(
      :customer_type, :first_name, :middle_name, :last_name, :company_name, :email, :mobile,
      :address, :state, :city, :pincode, :pan_no, :gst_no, :birth_date,
      :gender, :occupation, :annual_income, :nominee_name, :nominee_relation,
      :nominee_date_of_birth, :status, :birth_place, :height_feet, :weight_kg, :education,
      :marital_status, :business_job, :business_name, :type_of_duty, :additional_information,
      :added_by, :sub_agent, :age,
      documents_attributes: [:id, :document_type, :file, :_destroy],
      uploaded_documents_attributes: [:id, :title, :description, :document_type, :file, :uploaded_by, :_destroy],
      family_members_attributes: [
        :id, :first_name, :middle_name, :last_name, :birth_date, :age, :height_feet, :weight_kg,
        :gender, :relationship, :pan_no, :mobile, :additional_information, :_destroy,
        documents_attributes: [:id, :document_type, :file, :_destroy]
      ],
      corporate_members_attributes: [
        :id, :company_name, :mobile, :email, :state, :city, :address, :annual_income,
        :pan_no, :gst_no, :additional_information, :_destroy,
        documents_attributes: [:id, :document_type, :file, :_destroy]
      ]
    )
  end

  # For flat JSON structure (registration endpoint)
  def flat_customer_params
    params.permit(
      :customer_type, :first_name, :middle_name, :last_name, :company_name, :email, :mobile,
      :address, :state, :city, :pincode, :pan_no, :gst_no, :birth_date,
      :gender, :occupation, :annual_income, :nominee_name, :nominee_relation,
      :nominee_date_of_birth, :status, :birth_place, :height_feet, :weight_kg, :education,
      :marital_status, :business_job, :business_name, :type_of_duty, :additional_information,
      :added_by, :sub_agent, :age
    )
  end

  def customer_summary(customer)
    {
      id: customer.id,
      customer_type: customer.customer_type,
      display_name: customer.display_name,
      email: customer.email,
      mobile: customer.mobile,
      address: customer.address,
      state: customer.state,
      city: customer.city,
      status: customer.status,
      created_at: customer.created_at,
      updated_at: customer.updated_at
    }
  end

  def customer_details(customer)
    base_info = {
      id: customer.id,
      customer_type: customer.customer_type,
      status: customer.status,
      created_at: customer.created_at,
      updated_at: customer.updated_at
    }

    if customer.individual?
      base_info.merge({
        basic_info: {
          profile_image: customer.profile_image.attached? ? url_for(customer.profile_image) : nil,
          sub_agent: customer.sub_agent,
          first_name: customer.first_name,
          middle_name: customer.middle_name,
          last_name: customer.last_name,
          mobile: customer.mobile,
          email: customer.email
        },
        advance_details: {
          state: customer.state,
          city: customer.city,
          address: customer.address,
          birth_place: customer.birth_place,
          birth_date: customer.birth_date,
          age: customer.age,
          gender: customer.gender,
          height_feet: customer.height_feet,
          weight_kg: customer.weight_kg,
          education: customer.education,
          marital_status: customer.marital_status,
          business_job: customer.business_job,
          business_name: customer.business_name,
          type_of_duty: customer.type_of_duty,
          annual_income: customer.annual_income,
          pan_no: customer.pan_no,
          gst_no: customer.gst_no,
          additional_information: customer.additional_information
        },
        documents: customer.documents.map { |doc| document_info(doc) },
        uploaded_documents: customer.uploaded_documents.map { |doc| uploaded_document_info(doc) },
        family_members: customer.family_members.map { |member| family_member_info(member) },
        corporate_members: customer.corporate_members.map { |member| corporate_member_info(member) }
      })
    else
      base_info.merge({
        company_name: customer.company_name,
        email: customer.email,
        mobile: customer.mobile,
        address: customer.address,
        state: customer.state,
        city: customer.city,
        annual_income: customer.annual_income,
        pan_no: customer.pan_no,
        gst_no: customer.gst_no
      })
    end
  end

  def document_info(document)
    {
      id: document.id,
      document_type: document.document_type,
      file_url: document.file.attached? ? url_for(document.file) : nil
    }
  end

  def uploaded_document_info(document)
    {
      id: document.id,
      title: document.title,
      description: document.description,
      document_type: document.document_type,
      file_name: document.file_name,
      file_size: document.file_size,
      file_type: document.human_file_type,
      file_url: document.file.attached? ? url_for(document.file) : nil,
      uploaded_by: document.uploaded_by,
      created_at: document.created_at,
      updated_at: document.updated_at
    }
  end

  def family_member_info(member)
    {
      id: member.id,
      first_name: member.first_name,
      middle_name: member.middle_name,
      last_name: member.last_name,
      full_name: member.full_name,
      mobile: member.mobile,
      birth_date: member.birth_date,
      age: member.age,
      gender: member.gender,
      relationship: member.relationship,
      height_feet: member.height_feet,
      weight_kg: member.weight_kg,
      pan_no: member.pan_no,
      additional_information: member.additional_information,
      documents: member.documents.map { |doc| document_info(doc) }
    }
  end

  def corporate_member_info(member)
    {
      id: member.id,
      company_name: member.company_name,
      mobile: member.mobile,
      email: member.email,
      state: member.state,
      city: member.city,
      address: member.address,
      annual_income: member.annual_income,
      pan_no: member.pan_no,
      gst_no: member.gst_no,
      additional_information: member.additional_information,
      documents: member.documents.map { |doc| document_info(doc) }
    }
  end
end