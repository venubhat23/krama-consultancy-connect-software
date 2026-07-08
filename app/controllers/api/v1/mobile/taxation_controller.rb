class Api::V1::Mobile::TaxationController < Api::V1::Mobile::BaseController
  include MobileClientServiceCrud
  before_action :authenticate_customer!
  before_action :set_itr,          only: [:show_itr,          :update_itr,          :destroy_itr]
  before_action :set_tax_planning, only: [:show_tax_planning,  :update_tax_planning, :destroy_tax_planning]

  # GET /api/v1/mobile/taxation/summary
  def summary
    render json: {
      success: true,
      data: build_category_summary('taxation_itr', 'taxation_tax_planning')
    }
  end

  # ── ITR ──────────────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/taxation/itr
  def itr_list
    list_service('taxation_itr')
  end

  # POST /api/v1/mobile/taxation/itr
  def create_itr
    create_service('taxation_itr')
  end

  # GET /api/v1/mobile/taxation/itr/:id
  def show_itr
    show_service(@record)
  end

  # PATCH /api/v1/mobile/taxation/itr/:id
  def update_itr
    update_service(@record)
  end

  # DELETE /api/v1/mobile/taxation/itr/:id
  def destroy_itr
    destroy_service(@record)
  end

  # ── Tax Planning ──────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/taxation/tax_planning
  def tax_planning_list
    list_service('taxation_tax_planning')
  end

  # POST /api/v1/mobile/taxation/tax_planning
  def create_tax_planning
    create_service('taxation_tax_planning')
  end

  # GET /api/v1/mobile/taxation/tax_planning/:id
  def show_tax_planning
    show_service(@record)
  end

  # PATCH /api/v1/mobile/taxation/tax_planning/:id
  def update_tax_planning
    update_service(@record)
  end

  # DELETE /api/v1/mobile/taxation/tax_planning/:id
  def destroy_tax_planning
    destroy_service(@record)
  end

  private

  def set_itr
    @record = find_cs!('taxation_itr')
  end

  def set_tax_planning
    @record = find_cs!('taxation_tax_planning')
  end
end
