module Admin
  module Reports
    class SessionsController < ApplicationController
      before_action :authenticate_user!

      def index
        # Set timezone to India
        Time.zone = 'Asia/Kolkata'

        # Handle date range filter
        @date_range = params[:date_range] || '30_days'

        date_from = case @date_range
                    when '7_days'
                      7.days.ago
                    when '30_days'
                      30.days.ago
                    when '3_months'
                      3.months.ago
                    when '6_months'
                      6.months.ago
                    when '1_year'
                      1.year.ago
                    else
                      30.days.ago
                    end

        # Simple login session statistics - only basic counts
        @total_logins = Ahoy::Visit.where(started_at: date_from..Time.zone.now).count
        @unique_users = Ahoy::Visit.where(started_at: date_from..Time.zone.now).distinct.count(:user_id)
        @today_logins = Ahoy::Visit.where(started_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).count

        # Recent session activities (login and logout events)
        @recent_activities = begin
          # Try to use SessionActivity if the table exists
          if ActiveRecord::Base.connection.table_exists?('session_activities')
            SessionActivity.includes(:user)
                          .for_date_range(date_from, Time.zone.now)
                          .recent
                          .limit(50)
          else
            # Fallback to Ahoy visits (login events only)
            Ahoy::Visit
              .includes(:user)
              .where(started_at: date_from..Time.zone.now)
              .order(started_at: :desc)
              .limit(50)
              .map { |visit| OpenStruct.new(user: visit.user, activity_type: 'login', occurred_at: visit.started_at) }
          end
        rescue => e
          Rails.logger.error "Error fetching session activities: #{e.message}"
          []
        end

        # Logins by user type
        @logins_by_role = Ahoy::Visit
                          .joins(:user)
                          .where(started_at: date_from..Time.zone.now)
                          .group('users.user_type')
                          .count

        # Handle JSON requests for unique users modal
        respond_to do |format|
          format.html
          format.json do
            if params[:unique_users] == 'true'
              # First get unique user IDs to avoid GROUP BY issues
              unique_user_ids = Ahoy::Visit
                .where(started_at: date_from..Time.zone.now)
                .distinct
                .pluck(:user_id)
                .compact

              # Then get user data for each unique user
              unique_users_data = User.where(id: unique_user_ids).map do |user|
                session_count = Ahoy::Visit.where(user_id: user.id, started_at: date_from..Time.zone.now).count
                last_login = Ahoy::Visit.where(user_id: user.id).order(started_at: :desc).first&.started_at

                role_color = case user.user_type
                            when 'admin' then 'danger'
                            when 'agent' then 'primary'
                            when 'customer' then 'success'
                            when 'sub_agent' then 'info'
                            else 'secondary'
                            end

                {
                  name: "#{user.first_name} #{user.last_name}".strip.presence || user.email,
                  email: user.email,
                  role: user.user_type.humanize,
                  role_color: role_color,
                  session_count: session_count,
                  last_login: last_login ? last_login.in_time_zone('Asia/Kolkata').strftime('%b %d, %Y %I:%M %p') : 'Never'
                }
              end.sort_by { |u| -u[:session_count] }

              render json: { unique_users: unique_users_data }
            end
          end
        end
      end

      # API endpoint for real-time data
      def realtime_data
        Time.zone = 'Asia/Kolkata'

        # Get today's activities
        today_activities = if ActiveRecord::Base.connection.table_exists?('session_activities')
                            SessionActivity.for_date_range(Time.zone.now.beginning_of_day, Time.zone.now.end_of_day)
                          else
                            []
                          end

        # Get recent activities for realtime data
        recent_activities = begin
          if ActiveRecord::Base.connection.table_exists?('session_activities')
            SessionActivity.includes(:user)
                          .for_date_range(7.days.ago, Time.zone.now)
                          .recent
                          .limit(5)
          else
            # Fallback to Ahoy visits (login events only)
            Ahoy::Visit
              .includes(:user)
              .where(started_at: 7.days.ago..Time.zone.now)
              .order(started_at: :desc)
              .limit(5)
              .map { |visit| OpenStruct.new(user: visit.user, activity_type: 'login', occurred_at: visit.started_at) }
          end
        rescue => e
          Rails.logger.error "Error fetching recent activities: #{e.message}"
          []
        end

        data = {
          today_logins: today_activities.respond_to?(:logins) ? today_activities.logins.count : Ahoy::Visit.where(started_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).count,
          today_logouts: today_activities.respond_to?(:logouts) ? today_activities.logouts.count : 0,
          current_time: Time.zone.now.strftime("%B %d, %Y %I:%M:%S %p IST"),
          recent_activities: (recent_activities || []).first(5).map do |activity|
            occurred_time = activity.respond_to?(:occurred_at) ? activity.occurred_at : activity.started_at
            activity_type = activity.respond_to?(:activity_type) ? activity.activity_type : 'login'
            {
              user: activity.user ? "#{activity.user.first_name} #{activity.user.last_name}".strip.presence || activity.user.email : "Guest",
              activity_type: activity_type,
              occurred_at: occurred_time.in_time_zone('Asia/Kolkata').strftime("%I:%M %p")
            }
          end
        }

        respond_to do |format|
          format.json { render json: data }
        end
      end
    end
  end
end