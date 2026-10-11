ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  def sign_in_account(account)
    post login_path, params: { email: account.email }
    code = ActionMailer::Base.deliveries.last.body.decoded[/code is (\d{6})/, 1]
    post verify_login_path, params: { code: code }
    assert_response :see_other
  end
end
