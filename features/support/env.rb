require 'cucumber/rails'
require 'capybara/cucumber'
require 'selenium-webdriver'
require 'factory_bot_rails'
require 'rspec/matchers'

ActionController::Base.allow_rescue = false

begin
  DatabaseCleaner.strategy = :truncation
rescue NameError
  raise "You need to add database_cleaner to your Gemfile (in the :test group) if you wish to use it."
end

Cucumber::Rails::Database.javascript_strategy = :truncation

# Configure Capybara with headless Chrome
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1440,900')
  options.add_argument('--disable-web-security')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.default_driver = :headless_chrome
Capybara.javascript_driver = :headless_chrome
Capybara.default_max_wait_time = 10
Capybara.server = :puma, { Silent: true }

FactoryBot.definition_file_paths = [
  File.expand_path('../../factories', __FILE__)
]
FactoryBot.find_definitions

World(FactoryBot::Syntax::Methods)
World(RSpec::Matchers)

Before do
  # Two-phase request drain before each scenario:
  # 1. window.stop() cancels any browser-queued (not-yet-sent) requests.
  # 2. navigate to about:blank stops the page from firing new requests.
  # 3. A 300 ms sleep lets any already-sent TCP requests arrive at Puma
  #    and be processed while the users table is still intact, so Devise
  #    never sends a "sign-out" Set-Cookie that would corrupt the next
  #    scenario's session.  The cookies are then fully cleared by
  #    reset_sessions! below.
  begin
    session = Capybara.current_session
    begin
      session.execute_script("window.stop()")
    rescue => _e
      # Page may not be loaded yet — safe to ignore
    end
    session.driver.browser.navigate.to('about:blank')
    sleep 1.0
  rescue => e
    # Browser not yet started or already clean — safe to ignore
  end
  begin
    DatabaseCleaner.clean
  rescue => e
    warn "DatabaseCleaner.clean failed: #{e.message} — reconnecting"
    begin
      ActiveRecord::Base.connection_pool.disconnect!
      ActiveRecord::Base.establish_connection
    rescue => e2
      warn "Reconnect failed: #{e2.message}"
    end
    begin
      DatabaseCleaner.clean
    rescue => e3
      warn "DatabaseCleaner.clean retry failed: #{e3.message}"
    end
  end
  begin
    Capybara.reset_sessions!
    # Second cookie sweep: catch any late Set-Cookie responses that
    # arrived at Chrome AFTER reset_sessions! cleared the session.
    sleep 0.2
    Capybara.current_session.driver.browser.manage.delete_all_cookies
  rescue => e
    warn "Capybara.reset_sessions! failed: #{e.message} — restarting driver"
    begin
      Capybara.current_driver = Capybara.default_driver
    rescue => e2
      warn "Driver restart failed: #{e2.message}"
    end
  end
end
