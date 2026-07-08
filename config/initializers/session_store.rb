# Be sure to restart your server when you modify this file.

# Configure session cookies with larger size limit
Rails.application.config.session_store :cookie_store,
  key: '_insurebook_admin_session',
  secure: Rails.env.production?, # Only use secure cookies in production
  httponly: true,
  same_site: :lax, # Allow cookies to be sent with navigation but not cross-site requests
  expire_after: 2.weeks # Set session expiration to prevent unlimited growth