class Api::V1::Mobile::LoansController < Api::V1::Mobile::BaseController
  include MobileClientServiceCrud
  before_action :authenticate_customer!
  before_action :set_personal,  only: [:show_personal,  :update_personal,  :destroy_personal]
  before_action :set_home,      only: [:show_home,      :update_home,      :destroy_home]
  before_action :set_mortgage,  only: [:show_mortgage,  :update_mortgage,  :destroy_mortgage]
  before_action :set_business,  only: [:show_business,  :update_business,  :destroy_business]

  # GET /api/v1/mobile/loans/summary
  def summary
    render json: {
      success: true,
      data: build_category_summary(
        'loans_personal', 'loans_home', 'loans_mortgage', 'loans_business'
      )
    }
  end

  # ── Personal Loan ─────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/loans/personal
  def personal_list
    list_service('loans_personal')
  end

  # POST /api/v1/mobile/loans/personal
  def create_personal
    create_service('loans_personal')
  end

  # GET /api/v1/mobile/loans/personal/:id
  def show_personal
    show_service(@record)
  end

  # PATCH /api/v1/mobile/loans/personal/:id
  def update_personal
    update_service(@record)
  end

  # DELETE /api/v1/mobile/loans/personal/:id
  def destroy_personal
    destroy_service(@record)
  end

  # ── Home Loan ─────────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/loans/home
  def home_list
    list_service('loans_home')
  end

  # POST /api/v1/mobile/loans/home
  def create_home
    create_service('loans_home')
  end

  # GET /api/v1/mobile/loans/home/:id
  def show_home
    show_service(@record)
  end

  # PATCH /api/v1/mobile/loans/home/:id
  def update_home
    update_service(@record)
  end

  # DELETE /api/v1/mobile/loans/home/:id
  def destroy_home
    destroy_service(@record)
  end

  # ── Mortgage Loan ─────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/loans/mortgage
  def mortgage_list
    list_service('loans_mortgage')
  end

  # POST /api/v1/mobile/loans/mortgage
  def create_mortgage
    create_service('loans_mortgage')
  end

  # GET /api/v1/mobile/loans/mortgage/:id
  def show_mortgage
    show_service(@record)
  end

  # PATCH /api/v1/mobile/loans/mortgage/:id
  def update_mortgage
    update_service(@record)
  end

  # DELETE /api/v1/mobile/loans/mortgage/:id
  def destroy_mortgage
    destroy_service(@record)
  end

  # ── Business Loan ─────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/loans/business
  def business_list
    list_service('loans_business')
  end

  # POST /api/v1/mobile/loans/business
  def create_business
    create_service('loans_business')
  end

  # GET /api/v1/mobile/loans/business/:id
  def show_business
    show_service(@record)
  end

  # PATCH /api/v1/mobile/loans/business/:id
  def update_business
    update_service(@record)
  end

  # DELETE /api/v1/mobile/loans/business/:id
  def destroy_business
    destroy_service(@record)
  end

  private

  def set_personal = @record = find_cs!('loans_personal')
  def set_home     = @record = find_cs!('loans_home')
  def set_mortgage = @record = find_cs!('loans_mortgage')
  def set_business = @record = find_cs!('loans_business')
end
