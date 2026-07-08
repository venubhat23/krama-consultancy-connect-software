module TestHelpers
  # Submits the first (or selector-matched) form on the page by calling the
  # native HTMLFormElement.submit() prototype directly.  This bypasses ALL
  # JavaScript event listeners — including Bootstrap's needs-validation check
  # and Turbo's submit interceptor — so the server always receives the POST
  # and can return proper validation errors.
  def native_form_submit(selector = 'form')
    page.execute_script(<<~JS)
      (function() {
        var form = document.querySelector(#{selector.to_json});
        if (form) HTMLFormElement.prototype.submit.call(form);
      })();
    JS
  end

  def login_as_admin
    role = begin
      Role.find_or_create_by!(name: 'Admin') do |r|
        r.description = 'Administrator'
        r.status = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      Role.find_by!(name: 'Admin')
    end
    user = User.find_by(email: 'testadmin@drwise.com') || User.find_by(mobile: '9000000001')
    if user.nil?
      begin
        User.create!(
          first_name: 'Test', last_name: 'Admin',
          email: 'testadmin@drwise.com',
          password: 'password123', password_confirmation: 'password123',
          mobile: '9000000001', user_type: 'admin', role: role, status: true
        )
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        user = User.find_by(email: 'testadmin@drwise.com') || User.find_by(mobile: '9000000001')
        user.update!(password: 'password123', password_confirmation: 'password123')
      end
    else
      user.update!(password: 'password123', password_confirmation: 'password123')
    end
    attempts = 0
    begin
      attempts += 1
      visit '/users/sign_in'
      find('#user_login').set('testadmin@drwise.com')
      find('#user_password').set('password123')
      click_button 'Sign In'
      expect(page).to have_current_path(%r{/admin|/dashboard}, wait: 20)
    rescue RSpec::Expectations::ExpectationNotMetError
      raise if attempts >= 3
      sleep 1
      retry
    end
  end

  def create_test_prerequisites
    @insurance_company = InsuranceCompany.find_or_create_by!(name: 'LIC of India') do |c|
      c.status         = true
      c.code           = 'LIC'
      c.insurance_type = 'life'
    end

    @agency_code = AgencyCode.find_or_create_by!(code: 'AG001') do |a|
      a.insurance_type = 'Life Insurance'
      a.company_name   = 'LIC of India'
      a.agent_name     = 'Test Agent'
    end

    @distributor = Distributor.find_by(email: 'testdist@drwise.com') ||
                   Distributor.find_by(mobile: '9876543210') ||
                   Distributor.create!(
                     first_name: 'Test', last_name: 'Distributor',
                     email: 'testdist@drwise.com', mobile: '9876543210', role_id: 1
                   )

    @customer = Customer.find_or_create_by!(mobile: '9123456789') do |c|
      c.first_name             = 'Test'
      c.last_name              = 'Client'
      c.email                  = 'testclient@example.com'
      c.mobile                 = '9123456789'
      c.customer_type          = 'individual'
      c.birth_date             = '1985-01-01'
      c.nominee_name           = 'Test Nominee'
      c.nominee_relation       = 'spouse'
      c.nominee_date_of_birth  = '1988-06-15'
      c.status                 = true
    end

    SystemSetting.find_or_create_by!(key: 'company_expenses_percentage') do |s|
      s.value        = '3.0'
      s.setting_type = 'decimal'
      s.description  = 'Company expenses %'
    end
  end
end

World(TestHelpers)
