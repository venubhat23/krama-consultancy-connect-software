module ForumPortal
  class SupportTicketsController < ApplicationController
    include ConfigurablePagination

    before_action :set_ticket, only: [:show, :reply]

    def index
      tickets = SupportTicket.visible_to(current_user).with_list_includes.recent_first
      @tickets = paginate_records(tickets)
    end

    def show
      @replies = @ticket.replies.includes(:user).order(:created_at)
    end

    def create
      ticket = current_user.support_tickets.new(ticket_params)
      ticket.forum = @current_forum
      ticket.chapter = current_user.chapter if chapter_admin?

      if ticket.save
        redirect_to forum_portal_support_tickets_path, notice: 'Support ticket submitted.'
      else
        redirect_to forum_portal_support_tickets_path, alert: ticket.errors.full_messages.to_sentence
      end
    end

    def reply
      @ticket.replies.create!(user: current_user, body: params[:body])
      redirect_to forum_portal_support_ticket_path(@ticket), notice: 'Reply posted.'
    end

    private

    def set_ticket
      @ticket = SupportTicket.visible_to(current_user).find(params[:id])
    end

    def ticket_params
      params.require(:support_ticket).permit(:subject, :body, :priority)
    end
  end
end
