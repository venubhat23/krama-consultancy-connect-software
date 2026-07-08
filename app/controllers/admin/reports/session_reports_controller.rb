class Admin::Reports::SessionReportsController < Admin::Reports::BaseController
  def index
    redirect_to admin_reports_path, alert: 'Session reports are not available.'
  end
end
