require "test_helper"

class PilotTest < ActionDispatch::IntegrationTest
  setup do
    @old_user = ENV["ADMIN_USERNAME"]
    @old_password = ENV["ADMIN_PASSWORD"]
    ENV["ADMIN_USERNAME"] = "test-admin"
    ENV["ADMIN_PASSWORD"] = "test-password-for-this-suite"
  end

  teardown do
    ENV["ADMIN_USERNAME"] = @old_user
    ENV["ADMIN_PASSWORD"] = @old_password
  end

  def answers
    {
      name: "Alex Example", email: "alex@example.test", purpose: "Help local growers use surplus produce",
      experience: "Built an ordering system for a food co-operative.",
      working_style: "Figuring things out", engagement: "Freelance project",
      availability: "Two days a week from October", location: "London or remote",
      pay_expectations: "GBP 400 per day", consent: "1"
    }
  end

  def admin_headers
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("test-admin", "test-password-for-this-suite") }
  end

  test "public pages use semantic HTML without scripts or account requirements" do
    [ root_path, new_person_path, new_organisation_path, privacy_path, thanks_path ].each do |path|
      get path
      assert_response :success
      assert_select "html[lang=en]"
      assert_select "main", count: 1
      assert_select "h1", count: 1
      assert_select "script", count: 0
    end
  end

  test "a person applies and sees confirmation without exposing their details" do
    assert_difference "Submission.count", 1 do
      post people_path, params: { submission: answers.merge(kind: "organisation", status: "Introduced", notes: "injected") }
    end
    entry = Submission.last
    assert_equal "person", entry.kind
    assert_equal "Received", entry.status
    assert_nil entry.notes
    assert entry.consented_at
    assert_redirected_to thanks_path
    follow_redirect!
    assert_response :success
    assert_select "h1", text: /Thanks/
    assert_no_match "alex@example.test", response.body
  end

  test "organisation brief is stored and can be reviewed and updated privately" do
    post organisations_path, params: { submission: answers.except(:experience).merge(organisation_name: "Orchard Co-op", challenge: "We need help figuring this out.") }
    assert_redirected_to thanks_path
    entry = Submission.last
    assert_equal "organisation", entry.kind
    get admin_root_path, headers: admin_headers
    assert_response :success
    assert_select "a", text: "Orchard Co-op"
    get admin_submission_path(entry), headers: admin_headers
    assert_response :success
    assert_select "dd", text: /We need help figuring this out/
    assert_equal "no-store", response.headers["Cache-Control"]
    patch admin_submission_path(entry), headers: admin_headers, params: { submission: { status: "Needs a conversation", notes: "Clarify the time commitment.", email: "changed@example.test" } }
    assert_redirected_to admin_submission_path(entry)
    assert_equal "Needs a conversation", entry.reload.status
    assert_equal "alex@example.test", entry.email
    assert_equal "Clarify the time commitment.", entry.notes
  end

  test "invalid submissions preserve answers and associate errors with controls" do
    assert_no_difference "Submission.count" do
      post people_path, params: { submission: answers.merge(email: "invalid", consent: "0") }
    end
    assert_response :unprocessable_entity
    assert_select "input[name='submission[name]'][value='Alex Example']"
    assert_select "input#submission_email[aria-invalid=true][aria-describedby='email-hint email-error']"
    assert_select "#email-error", text: /invalid/
    assert_select ".error-summary a[href='#submission_consent']"
  end

  test "required context and permission are enforced on the server" do
    assert_no_difference "Submission.count" do
      post organisations_path, params: { submission: { name: "Alex" } }
    end
    assert_response :unprocessable_entity
    assert_select ".error-summary a[href='#submission_challenge']"
    assert_select ".error-summary a[href='#submission_purpose']"
    assert_select ".error-summary a[href='#submission_consent']"
  end

  test "unsafe URLs and overlong answers are rejected" do
    assert_no_difference "Submission.count" do
      post people_path, params: { submission: answers.merge(website: "javascript:alert(1)", purpose: "x" * 5001) }
    end
    assert_response :unprocessable_entity
  end

  test "honeypot submissions are not stored" do
    assert_no_difference "Submission.count" do
      post people_path, params: { submission: answers.merge(website_confirmation: "spam") }
    end
    assert_redirected_to thanks_path
  end

  test "every admin action requires authentication and fails closed without credentials" do
    entry = Submission.create!(answers.merge(kind: "person"))
    [ admin_root_path, admin_submissions_path, admin_submission_path(entry) ].each do |path|
      get path
      assert_response :unauthorized
      assert_no_match entry.email, response.body
    end
    patch admin_submission_path(entry), params: { submission: { status: "Introduced" } }
    assert_response :unauthorized
    assert_equal "Received", entry.reload.status
    get admin_root_path, headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("test-admin", "wrong") }
    assert_response :unauthorized
    ENV.delete("ADMIN_PASSWORD")
    get admin_root_path, headers: admin_headers
    assert_response :service_unavailable
  end

  test "admin filters applications and rejects unknown statuses" do
    person = Submission.create!(answers.merge(kind: "person"))
    Submission.create!(answers.merge(kind: "organisation", organisation_name: "Orchard", challenge: "Reduce waste"))
    get admin_root_path, headers: admin_headers, params: { kind: "organisation" }
    assert_response :success
    assert_select ".application-list li", count: 1
    assert_select ".application-list h2", text: "Orchard"
    patch admin_submission_path(person), headers: admin_headers, params: { submission: { status: "unknown" } }
    assert_response :unprocessable_entity
    assert_equal "Received", person.reload.status
  end

  test "application content cannot inject scripts in admin pages" do
    entry = Submission.create!(answers.merge(kind: "person", purpose: '<script>alert("bad")</script>'))
    get admin_submission_path(entry), headers: admin_headers
    assert_response :success
    assert_select "script", count: 0
  end

  test "a browser session can navigate and submit with CSRF protection enabled" do
    old_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get root_path
    assert_response :success
    get new_person_path
    assert_response :success
    token = css_select("input[name=authenticity_token]").first["value"]
    assert_difference "Submission.count", 1 do
      post people_path, params: { authenticity_token: token, submission: answers }
    end
    assert_redirected_to thanks_path
    follow_redirect!
    assert_response :success
  ensure
    ActionController::Base.allow_forgery_protection = old_setting
  end

  test "public forms reject submissions without a CSRF token" do
    old_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference "Submission.count" do
      post people_path, params: { submission: answers }
    end
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = old_setting
  end
end
