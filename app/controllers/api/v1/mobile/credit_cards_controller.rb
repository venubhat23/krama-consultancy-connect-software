class Api::V1::Mobile::CreditCardsController < Api::V1::Mobile::BaseController
  include MobileClientServiceCrud
  before_action :authenticate_customer!
  before_action :set_rewards,  only: [:show_rewards,  :update_rewards,  :destroy_rewards]
  before_action :set_business, only: [:show_business, :update_business, :destroy_business]
  before_action :set_travel,   only: [:show_travel,   :update_travel,   :destroy_travel]

  # GET /api/v1/mobile/credit_cards/summary
  def summary
    render json: {
      success: true,
      data: build_category_summary(
        'credit_card_rewards', 'credit_card_business', 'credit_card_travel'
      )
    }
  end

  # ── Rewards Card ──────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/credit_cards/rewards
  def rewards_list
    list_service('credit_card_rewards')
  end

  # POST /api/v1/mobile/credit_cards/rewards
  def create_rewards
    create_service('credit_card_rewards')
  end

  # GET /api/v1/mobile/credit_cards/rewards/:id
  def show_rewards
    show_service(@record)
  end

  # PATCH /api/v1/mobile/credit_cards/rewards/:id
  def update_rewards
    update_service(@record)
  end

  # DELETE /api/v1/mobile/credit_cards/rewards/:id
  def destroy_rewards
    destroy_service(@record)
  end

  # ── Business Card ─────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/credit_cards/business
  def business_list
    list_service('credit_card_business')
  end

  # POST /api/v1/mobile/credit_cards/business
  def create_business
    create_service('credit_card_business')
  end

  # GET /api/v1/mobile/credit_cards/business/:id
  def show_business
    show_service(@record)
  end

  # PATCH /api/v1/mobile/credit_cards/business/:id
  def update_business
    update_service(@record)
  end

  # DELETE /api/v1/mobile/credit_cards/business/:id
  def destroy_business
    destroy_service(@record)
  end

  # ── Travel Card ───────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/credit_cards/travel
  def travel_list
    list_service('credit_card_travel')
  end

  # POST /api/v1/mobile/credit_cards/travel
  def create_travel
    create_service('credit_card_travel')
  end

  # GET /api/v1/mobile/credit_cards/travel/:id
  def show_travel
    show_service(@record)
  end

  # PATCH /api/v1/mobile/credit_cards/travel/:id
  def update_travel
    update_service(@record)
  end

  # DELETE /api/v1/mobile/credit_cards/travel/:id
  def destroy_travel
    destroy_service(@record)
  end

  private

  def set_rewards  = @record = find_cs!('credit_card_rewards')
  def set_business = @record = find_cs!('credit_card_business')
  def set_travel   = @record = find_cs!('credit_card_travel')
end
