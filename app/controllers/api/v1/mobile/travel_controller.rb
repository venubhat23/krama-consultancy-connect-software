class Api::V1::Mobile::TravelController < Api::V1::Mobile::BaseController
  include MobileClientServiceCrud
  before_action :authenticate_customer!
  before_action :set_domestic,      only: [:show_domestic,      :update_domestic,      :destroy_domestic]
  before_action :set_international, only: [:show_international, :update_international, :destroy_international]

  # GET /api/v1/mobile/travel/summary
  def summary
    render json: {
      success: true,
      data: build_category_summary('travel_domestic', 'travel_international')
    }
  end

  # ── Domestic Travel ───────────────────────────────────────────────────────────

  # GET /api/v1/mobile/travel/domestic
  def domestic_list
    list_service('travel_domestic')
  end

  # POST /api/v1/mobile/travel/domestic
  def create_domestic
    create_service('travel_domestic')
  end

  # GET /api/v1/mobile/travel/domestic/:id
  def show_domestic
    show_service(@record)
  end

  # PATCH /api/v1/mobile/travel/domestic/:id
  def update_domestic
    update_service(@record)
  end

  # DELETE /api/v1/mobile/travel/domestic/:id
  def destroy_domestic
    destroy_service(@record)
  end

  # ── International Travel ──────────────────────────────────────────────────────

  # GET /api/v1/mobile/travel/international
  def international_list
    list_service('travel_international')
  end

  # POST /api/v1/mobile/travel/international
  def create_international
    create_service('travel_international')
  end

  # GET /api/v1/mobile/travel/international/:id
  def show_international
    show_service(@record)
  end

  # PATCH /api/v1/mobile/travel/international/:id
  def update_international
    update_service(@record)
  end

  # DELETE /api/v1/mobile/travel/international/:id
  def destroy_international
    destroy_service(@record)
  end

  private

  def set_domestic      = @record = find_cs!('travel_domestic')
  def set_international = @record = find_cs!('travel_international')
end
