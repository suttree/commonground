require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  setup do
    @old_credentials = ENV.values_at("ADMIN_USERNAME", "ADMIN_PASSWORD")
    ENV["ADMIN_USERNAME"] = "test-admin"
    ENV["ADMIN_PASSWORD"] = "test-password"
    @headers = { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("test-admin", "test-password") }
    @account = Account.create!(email: "admin@example.test")
    @profile = Submission.create!(kind: "person", profile_version: 2, name: "Private applicant", email: "private@example.test",
      purpose: "Useful work", experience: "Projects", consent: "1")
    @contact_entry = @profile.contact_requests.create!(intent: "problem", name: "Visitor", email: "visitor@example.test",
      message: "A private request", consent: "1")
    @paths = [ admin_root_path, admin_submissions_path, admin_submission_path(@profile),
      admin_contact_requests_path, admin_contact_request_path(@contact_entry), admin_portfolio_image_path(999) ]
  end

  teardown do
    ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = @old_credentials
  end

  test "basic auth alone cannot read or change admin data" do
    @paths.each do |path|
      get path, headers: @headers
      assert_redirected_to login_path
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_no_match @profile.email, response.body
    end
    patch admin_submission_path(@profile), headers: @headers, params: { submission: { published: false } }
    assert_redirected_to login_path
    assert @profile.reload.published?
  end

  test "ordinary accounts cannot access admin even with basic auth" do
    assert_not @account.admin?
    sign_in_account(@account)
    @paths.each do |path|
      get path, headers: @headers
      assert_response :forbidden
    end
    patch admin_submission_path(@profile), headers: @headers, params: { submission: { published: false } }
    assert_response :forbidden
    assert @profile.reload.published?
    get root_path
    assert_select "a[href='/admin']", count: 0
  end

  test "admins still need basic auth and lose access after revocation or logout" do
    @account.update!(admin: true)
    sign_in_account(@account)
    get root_path
    assert_select "a[href='/admin']", text: "Admin"
    get admin_root_path
    assert_response :unauthorized
    assert response.headers["WWW-Authenticate"].present?
    get admin_root_path, headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("test-admin", "wrong") }
    assert_response :unauthorized
    get admin_root_path, headers: @headers
    assert_response :success
    @account.update!(admin: false)
    get admin_root_path, headers: @headers
    assert_response :forbidden
    @account.update!(admin: true)
    delete logout_path
    get admin_root_path, headers: @headers
    assert_redirected_to login_path
  end

  test "expired account sessions cannot use cached basic auth" do
    @account.update!(admin: true)
    sign_in_account(@account)
    travel 31.days do
      get admin_root_path, headers: @headers
      assert_redirected_to login_path
    end
  end

  test "login parameters cannot grant admin privileges" do
    post login_path, params: { email: @account.email, admin: true, account: { admin: true } }
    code = ActionMailer::Base.deliveries.last.body.decoded[/^(\d{6})$/, 1]
    post verify_login_path, params: { code: code, admin: true, account: { admin: true } }
    assert_not @account.reload.admin?
    get admin_root_path, headers: @headers
    assert_response :forbidden
  end
end
