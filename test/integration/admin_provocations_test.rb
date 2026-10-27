require "test_helper"

class AdminProvocationsTest < ActionDispatch::IntegrationTest
  setup do
    @credentials = ENV.values_at("ADMIN_USERNAME", "ADMIN_PASSWORD")
    ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = "admin", "password"
    @headers = { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "password") }
    @admin = Account.create!(email: "questions-admin@example.test", admin: true)
  end

  teardown do
    ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = @credentials
  end

  test "admin creates edits publishes revises and retires without changing answered wording" do
    sign_in_account(@admin)
    get new_admin_provocation_path, headers: @headers
    assert_response :success
    post admin_provocations_path, headers: @headers, params: { provocation: { question: "First wording?", goal_id: "12", position: 5, status: "draft" } }
    question = Provocation.order(:id).last
    patch admin_provocation_path(question), headers: @headers, params: { provocation: { question: "Better wording?", status: "published" } }
    assert_equal "Better wording?", question.reload.question
    patch admin_provocation_path(question), headers: @headers, params: { provocation: { question: "Wrong wording?" } }
    assert_response :unprocessable_entity
    assert_equal "Better wording?", question.reload.question
    patch admin_provocation_path(question), headers: @headers, params: { provocation: { status: "draft" } }
    assert_response :unprocessable_entity
    assert_difference "Provocation.count", 1 do
      post revise_admin_provocation_path(question), headers: @headers
    end
    revision = Provocation.order(:id).last
    assert_equal "draft", revision.status
    assert_not_equal question.key, revision.key
    patch admin_provocation_path(question), headers: @headers, params: { provocation: { status: "retired", position: 8 } }
    assert_equal "retired", question.reload.status
    get admin_provocations_path, headers: @headers
    assert_response :success
  end

  test "ordinary member cannot manage provocations" do
    @admin.update!(admin: false)
    sign_in_account(@admin)
    get admin_provocations_path, headers: @headers
    assert_response :forbidden
    assert_no_difference "Provocation.count" do
      post admin_provocations_path, headers: @headers, params: { provocation: { question: "No?", goal_id: "1", position: 1, status: "published" } }
    end
    assert_response :forbidden
  end
end
