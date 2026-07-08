class Ahoy::Store < Ahoy::DatabaseStore
  # Minimal visit tracking - only essential data for login/logout
  def visit_data
    data = super

    # Only track minimal essential data
    {
      visit_token: data[:visit_token],
      visitor_token: data[:visitor_token],
      user_id: data[:user_id],
      started_at: data[:started_at]
    }
  end

  # Don't track any events - only basic login/logout visits
  def track_event(data)
    nil
  end
end

# Disable JavaScript tracking to prevent excessive data collection
Ahoy.api = false

# Disable geocoding - no need for location tracking
Ahoy.geocode = false

# Track visits only when explicitly needed (login/logout)
Ahoy.server_side_visits = :when_needed

# Don't track bot visits
Ahoy.track_bots = false

# Minimal cookie settings
Ahoy.cookie_domain = :all
Ahoy.cookie_options = { httponly: true, secure: Rails.env.production? }

# Short visit duration to keep sessions minimal
Ahoy.visit_duration = 1.hour

# Only track login/logout - skip all other requests
Ahoy.exclude_method = lambda do |controller, request|
  # Only track authentication related paths for login/logout
  auth_paths = ['/users/sign_in', '/users/sign_out']

  # Skip tracking unless it's a login/logout path
  !auth_paths.any? { |path| request.path == path }
end
