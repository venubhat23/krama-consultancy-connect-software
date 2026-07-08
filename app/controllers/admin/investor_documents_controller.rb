class Admin::InvestorDocumentsController < Admin::ApplicationController
  before_action :set_investor
  before_action :set_investor_document, only: [:destroy]

  # DELETE /admin/investors/:investor_id/investor_documents/:id
  def destroy
    # Delete from R2 if it's an R2 document
    if @investor_document.has_r2_document?
      @investor_document.delete_from_r2
    end

    # ActiveStorage will handle its own cleanup when the record is destroyed
    @investor_document.destroy
    redirect_to edit_admin_investor_path(@investor), notice: 'Document was successfully deleted.'
  end

  private

  def set_investor
    @investor = Investor.find(params[:investor_id])
  end

  def set_investor_document
    @investor_document = @investor.investor_documents.find(params[:id])
  end
end