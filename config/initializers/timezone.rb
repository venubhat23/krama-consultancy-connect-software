# Set default timezone to India Standard Time
Rails.application.configure do
  config.time_zone = 'Asia/Kolkata'
  # Keep UTC for database storage, but display in IST
  config.active_record.default_timezone = :utc
end

# Configure Groupdate gem to use IST for display
Groupdate.time_zone = 'Asia/Kolkata' if defined?(Groupdate)