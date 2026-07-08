class Admin::SupportTicketsController < Admin::SuperAdminBaseController
  include ConfigurablePagination

  before_action :set_ticket, only: [:show, :reply, :change_status]

  def index
    tickets = SupportTicket.with_list_includes.recent_first
    tickets = tickets.where(status: SupportTicket.statuses[params[:status]]) if params[:status].present?
    @tickets = paginate_records(tickets)
  end

  def show
    @replies = @ticket.replies.includes(:user).order(:created_at)
  end

  def reply
    @ticket.replies.create!(user: current_user, body: params[:body])
    redirect_to admin_platform_support_ticket_path(@ticket), notice: 'Reply posted.'
  end

  def change_status
    @ticket.update!(status: params[:status])
    redirect_to admin_platform_support_ticket_path(@ticket), notice: "Ticket status set to #{@ticket.status.humanize}."
  end

  private

  def set_ticket
    @ticket = SupportTicket.find(params[:id])
  end
end
