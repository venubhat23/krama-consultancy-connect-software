class Admin::BusinessPlansController < Admin::SuperAdminBaseController
  before_action :set_business_plan, only: [:show, :edit, :update, :destroy]

  def index
    @business_plans = BusinessPlan.ordered
  end

  def show
    @forums = @business_plan.forums.includes(:business_plan).order(:name)
  end

  def new
    @business_plan = BusinessPlan.new
  end

  def create
    @business_plan = BusinessPlan.new(business_plan_params)
    if @business_plan.save
      redirect_to admin_business_plans_path, notice: "#{@business_plan.name} plan created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @business_plan.update(business_plan_params)
      redirect_to admin_business_plans_path, notice: "#{@business_plan.name} plan updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @business_plan.forums.exists?
      redirect_to admin_business_plans_path, alert: "Can't delete #{@business_plan.name} — forums are still on this plan."
    else
      @business_plan.destroy
      redirect_to admin_business_plans_path, notice: "#{@business_plan.name} plan deleted."
    end
  end

  private

  def set_business_plan
    @business_plan = BusinessPlan.find(params[:id])
  end

  def business_plan_params
    params.require(:business_plan).permit(:key, :name, :price, :chapter_limit, :member_limit, :description, :active, :position)
  end
end
