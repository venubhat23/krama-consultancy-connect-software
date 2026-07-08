module ForumPortal
  class ApplicationController < ::ApplicationController
    before_action :ensure_forum_or_chapter_admin
    before_action :verify_session_token!
    before_action :set_current_forum

    private

    def ensure_forum_or_chapter_admin
      unless current_user&.forum_admin? || current_user&.chapter_admin?
        redirect_to root_path, alert: 'Access denied. Forum or chapter admin privileges required.'
      end
    end

    # Lets a super_admin's "force logout" bump of session_token actually end this session.
    def verify_session_token!
      return unless current_user

      session[:forum_session_token] ||= current_user.session_token
      if session[:forum_session_token] != current_user.session_token
        sign_out(current_user)
        redirect_to new_user_session_path, alert: 'You have been signed out remotely. Please sign in again.'
      end
    end

    def set_current_forum
      @current_forum = current_user.forum
      unless @current_forum
        sign_out(current_user)
        redirect_to new_user_session_path, alert: 'Your account is not linked to a forum.'
      end
    end

    def chapter_admin?
      current_user.chapter_admin?
    end

    # Chapters this user may manage: forum_admin sees all of their forum's chapters,
    # chapter_admin sees only their own.
    def visible_chapters
      chapter_admin? ? Chapter.where(id: current_user.chapter_id) : @current_forum.chapters
    end

    # Members (role == member) this user may manage, scoped the same way.
    def visible_members
      base = User.where(user_type: 'member', forum_id: @current_forum.id)
      chapter_admin? ? base.where(chapter_id: current_user.chapter_id) : base
    end
  end
end
