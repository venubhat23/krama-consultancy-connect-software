module MemberPortal
  class SupportTicketsController < ApplicationController
    include ConfigurablePagination

    before_action :set_ticket, only: [:show, :reply]

    def index
      tickets = current_user.support_tickets.with_list_includes.recent_first
      @tickets = paginate_records(tickets)
    end

    def show
      @replies = @ticket.replies.includes(:user).order(:created_at)
    end

    def create
      ticket = current_user.support_tickets.new(ticket_params)
      ticket.forum = current_user.forum
      ticket.chapter = current_user.chapter

      if ticket.save
        redirect_to member_portal_support_tickets_path, notice: 'Support ticket submitted.'
      else
        redirect_to member_portal_support_tickets_path, alert: ticket.errors.full_messages.to_sentence
      end
    end

    def reply
      @ticket.replies.create!(user: current_user, body: params[:body])
      redirect_to member_portal_support_ticket_path(@ticket), notice: 'Reply posted.'
    end

    private

    def set_ticket
      @ticket = current_user.support_tickets.find(params[:id])
    end

    def ticket_params
      params.require(:support_ticket).permit(:subject, :body, :priority)
    end
  end
end
