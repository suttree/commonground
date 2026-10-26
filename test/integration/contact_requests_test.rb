require "test_helper"

class ContactRequestsTest < ActionDispatch::IntegrationTest
  setup do
    @recipient = Submission.create!(kind: "person", profile_version: 2, name: "Nika", email: "private@example.test",
      purpose: "Useful work", experience: "Projects", consent: "1", published: true)
    @valid = { intent: "problem", name: "Visitor", email: "visitor@example.test", message: "A shared project", consent: "1" }
  end

  test "each action opens a preselected form and stores a private request" do
    ContactRequest::OPTIONS.each_key do |intent|
      get new_profile_contact_path(@recipient.public_slug, intent: intent)
      assert_response :success
      assert_select "input[type=radio][name=\"contact_request[intent]\"]", count: 3
      assert_select "input[type=radio][checked]", count: 1
      assert_select "input[type=radio][value=?][checked]", intent
      assert_no_match @recipient.email, response.body
      assert_difference "ContactRequest.count", 1 do
        post profile_contact_path(@recipient.public_slug), params: { contact_request: @valid.merge(intent: intent, submission_id: 999, target_ids: [ "1.1" ]) }
      end
      request = ContactRequest.last
      assert_equal @recipient.id, request.submission_id
      assert_equal intent, request.intent
      assert request.consented_at.present?
      assert_empty request.target_ids
      assert_redirected_to profile_contact_thanks_path(@recipient.public_slug)
    end
  end

  test "validation retains input and unpublished profiles cannot receive requests" do
    [ { consent: "0" }, { intent: "invalid" }, { email: "invalid" }, { message: "" }, { website_confirmation: "spam" } ].each do |invalid|
      assert_no_difference "ContactRequest.count" do
        post profile_contact_path(@recipient.public_slug), params: { contact_request: @valid.merge(invalid) }
      end
      assert_response :unprocessable_entity
    end
    @recipient.update!(published: false)
    get new_profile_contact_path(@recipient.public_slug)
    assert_response :not_found
    assert_no_difference "ContactRequest.count" do
      post profile_contact_path(@recipient.public_slug), params: { contact_request: @valid }
    end
    assert_response :not_found
  end

  test "quiz suggestions are included only with explicit choice" do
    post quiz_path, params: { question: 0, answer: "0" }
    post profile_contact_path(@recipient.public_slug), params: { contact_request: @valid.merge(include_priorities: "1") }
    assert_equal %w[2.1 1.3], ContactRequest.last.target_ids
    post profile_contact_path(@recipient.public_slug), params: { contact_request: @valid }
    assert_empty ContactRequest.last.target_ids
  end

  test "requests are available only through authenticated admin" do
    post profile_contact_path(@recipient.public_slug), params: { contact_request: @valid }
    entry = ContactRequest.last
    old_user, old_password = ENV.values_at("ADMIN_USERNAME", "ADMIN_PASSWORD")
    ENV["ADMIN_USERNAME"] = "test-admin"
    ENV["ADMIN_PASSWORD"] = "test-password"
    get admin_contact_request_path(entry)
    assert_response :unauthorized
    auth = ActionController::HttpAuthentication::Basic.encode_credentials("test-admin", "test-password")
    sign_in_account(Account.create!(email: "admin@example.test", admin: true))
    get admin_contact_requests_path, headers: { "HTTP_AUTHORIZATION" => auth }
    assert_response :success
    get admin_contact_request_path(entry), headers: { "HTTP_AUTHORIZATION" => auth }
    assert_response :success
    assert_includes response.body, @valid[:message]
    assert_equal "no-store", response.headers["Cache-Control"]
  ensure
    ENV["ADMIN_USERNAME"] = old_user
    ENV["ADMIN_PASSWORD"] = old_password
  end
end
