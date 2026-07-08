Given('I am logged in as admin') do
  create_test_prerequisites
  login_as_admin
end

Given('test prerequisites exist') do
  create_test_prerequisites
end
