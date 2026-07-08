class Admin::FamilyMembersController < Admin::ApplicationController
  before_action :set_customer
  before_action :set_family_member, only: [:show, :edit, :update, :destroy]

  # GET /admin/customers/:customer_id/family_members
  def index
    @family_members = @customer.family_members.order(:created_at)
  end

  # GET /admin/customers/:customer_id/family_members/1
  def show
  end

  # GET /admin/customers/:customer_id/family_members/new
  def new
    @family_member = @customer.family_members.build
  end

  # GET /admin/customers/:customer_id/family_members/1/edit
  def edit
  end

  # POST /admin/customers/:customer_id/family_members
  def create
    @family_member = @customer.family_members.build(family_member_params.except(:documents))

    # Handle document uploads separately
    documents = params[:family_member][:documents]
    if documents.present? && documents.is_a?(Array)
      documents.each do |document_file|
        # Skip if the file is blank, empty string, or not a file object
        next if document_file.blank? || document_file == "" || !document_file.respond_to?(:original_filename)

        # Create document with required attributes
        @family_member.documents.build(
          file: document_file,
          title: document_file.original_filename,
          document_type: 'other', # Default to 'other' or you can add logic to determine type
          uploaded_by: current_user&.email || 'system'
        )
      end
    end

    if @family_member.save
      redirect_to admin_customer_family_member_path(@customer, @family_member), notice: 'Family member was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/customers/:customer_id/family_members/1
  def update
    # Update family member attributes except documents
    @family_member.assign_attributes(family_member_params.except(:documents))

    # Handle document uploads separately
    documents = params[:family_member][:documents]
    if documents.present? && documents.is_a?(Array)
      documents.each do |document_file|
        # Skip if the file is blank, empty string, or not a file object
        next if document_file.blank? || document_file == "" || !document_file.respond_to?(:original_filename)

        # Create document with required attributes
        @family_member.documents.build(
          file: document_file,
          title: document_file.original_filename,
          document_type: 'other', # Default to 'other' or you can add logic to determine type
          uploaded_by: current_user&.email || 'system'
        )
      end
    end

    if @family_member.save
      redirect_to admin_customer_family_member_path(@customer, @family_member), notice: 'Family member was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/customers/:customer_id/family_members/1
  def destroy
    @family_member.destroy
    redirect_to admin_customer_family_members_path(@customer), notice: 'Family member was successfully deleted.'
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def set_family_member
    @family_member = @customer.family_members.find(params[:id])
  end

  def family_member_params
    params.require(:family_member).permit(
      :first_name, :middle_name, :last_name, :birth_date, :age, :height_feet, :weight_kg, :gender, :relationship,
      :pan_no, :mobile, :additional_information,
      documents_attributes: [:id, :document_type, :file, :_destroy]
    )
  end
end