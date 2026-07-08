module MemberPortal
  class ApplicationController < ::ApplicationController
    before_action :ensure_member
    before_action :verify_session_token!

    private

    def ensure_member
      unless current_user&.member?
        redirect_to root_path, alert: 'Access denied. Member privileges required.'
      end
    end

    def verify_session_token!
      return unless current_user

      session[:member_session_token] ||= current_user.session_token
      if session[:member_session_token] != current_user.session_token
        sign_out(current_user)
        redirect_to new_user_session_path, alert: 'You have been signed out remotely. Please sign in again.'
      end
    end
  end
end
