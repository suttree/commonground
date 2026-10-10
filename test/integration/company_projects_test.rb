require "test_helper"

class CompanyProjectsTest < ActionDispatch::IntegrationTest
  setup do
    @account = Account.create!(email: "owner@example.test")
    @person = make_profile("person", @account)
    @company = make_profile("organisation", @account)
    @other = make_profile("organisation", Account.create!(email: "other@example.test"))
    @attributes = { title: "Company project", description: "Grow food", objectives: "Open a garden", location: "Bristol", status: "active" }
    post login_path, params: { email: @account.email }
    code = ActionMailer::Base.deliveries.last.body.decoded[/code is (\d{6})/, 1]
    post verify_login_path, params: { code: code }
  end

  def make_profile(kind, account)
    Submission.create!(account: account, kind: kind, name: "Alex", email: account.email, profile_version: 2,
      purpose: "Community", experience: "Gardening", consent: "1", organisation_name: "Garden Company",
      mission: "Help", offering: "Gardens", challenge_kind: "Goals", challenge: "Grow")
  end

  test "personal account starts company project which appears on its company profile" do
    get new_challenge_path
    assert_select "select[name='challenge[submission_id]'] option", count: 2
    assert_select "select[name='challenge[submission_id]'] option[value='#{@other.id}']", count: 0
    post challenges_path, params: { challenge: @attributes.merge(submission_id: @company.id) }
    entry = @company.challenges.last
    assert entry
    assert_redirected_to challenge_path(entry)
    assert_empty @person.challenges
    get challenge_path(entry)
    assert_select "p", text: "On behalf of Garden Company" do
      assert_select "a[href='#{profile_path(@company.public_slug)}']"
    end
    assert_select "a[href='#{edit_challenge_path(entry)}']"
    get edit_challenge_path(entry)
    assert_response :success
    patch challenge_path(entry), params: { challenge: { title: "Updated company project", submission_id: @other.id } }
    assert_response :not_found
    assert_equal @company.id, entry.reload.submission_id
    get challenge_collaborator_invitations_path(entry)
    assert_response :success
    get profile_path(@company.public_slug)
    assert_select "a[href='#{challenge_path(entry)}']"
    get profile_path(@person.public_slug)
    assert_select "a[href='#{challenge_path(entry)}']", count: 0
    patch switch_profile_path, params: { selected_profile_id: @company.id }
    get dashboard_path
    assert_select "a[href='#{challenge_path(entry)}']"
    patch challenge_path(entry), params: { challenge: { status: "completed", project_role: "Founder", context: "Local", approach: "Planting", results: "A garden" } }
    assert entry.reload.completed?
    get profile_path(@company.public_slug)
    assert_select "#projects h2", text: "Projects"
    assert_select "a[href='#{challenge_path(entry)}']"
  end

  test "existing personal work can be moved to an owned company" do
    entry = @person.challenges.create!(@attributes)
    patch challenge_path(entry), params: { challenge: { submission_id: @company.id } }
    assert_redirected_to challenge_path(entry)
    assert_equal @company.id, entry.reload.submission_id
    get profile_path(@company.public_slug)
    assert_select "a[href='#{challenge_path(entry)}']"
    second = @person.challenges.create!(@attributes.merge(title: "Personal project"))
    patch challenge_path(second), params: { challenge: { submission_id: @company.id } }
    assert_response :unprocessable_entity
    assert_equal @person.id, second.reload.submission_id
  end

  test "switching profiles protects stale forms and isolates quiz answers" do
    get edit_account_profile_path
    get quiz_path
    post quiz_path, params: { profile_id: @person.id, question: 0, answer: "0" }
    patch switch_profile_path, params: { selected_profile_id: @company.id }
    get edit_account_profile_path
    assert_select "input[name='submission[organisation_name]']"
    patch account_profile_path, params: { profile_id: @person.id, submission: { name: "Wrong profile" } }
    assert_response :not_found
    assert_equal "Alex", @person.reload.name
    assert_equal "Alex", @company.reload.name
    post quiz_path, params: { profile_id: @person.id, question: 1, answer: "0" }
    assert_response :not_found
    assert_nil session[:quiz_answers]
    patch account_profile_path, params: { profile_id: @company.id, submission: { organisation_name: "Updated company" } }
    assert_redirected_to dashboard_path
    assert_equal "Updated company", @company.reload.organisation_name
    patch switch_profile_path, params: { selected_profile_id: @other.id }
    assert_response :not_found
    get dashboard_path
    assert_select "h1 a", text: "Updated company"
  end

  test "unowned company cannot be selected or receive a project and private work stays protected" do
    get new_challenge_path(submission_id: @other.id)
    assert_response :not_found
    assert_no_difference "Challenge.count" do
      post challenges_path, params: { challenge: @attributes.merge(submission_id: @other.id) }
    end
    assert_response :not_found
    entry = @company.challenges.create!(@attributes.merge(status: "draft"))
    get challenge_path(entry)
    assert_response :success
    get edit_challenge_path(entry)
    assert_response :success
    delete logout_path
    get challenge_path(entry)
    assert_response :not_found
    post login_path, params: { email: @other.email }
    code = ActionMailer::Base.deliveries.last.body.decoded[/code is (\d{6})/, 1]
    post verify_login_path, params: { code: code }
    get edit_challenge_path(entry)
    assert_response :not_found
    get challenge_collaborator_invitations_path(entry)
    assert_response :not_found
  end

  test "invitation acceptance credits the selected owned profile and rejects stale forms" do
    entry = @other.challenges.create!(@attributes)
    invitation = entry.collaborator_invitations.create!(email: @account.email, expires_at: 14.days.from_now)
    get invitation_path(token: invitation.token)
    assert_select "input[name=profile_id][value='#{@person.id}']"
    patch switch_profile_path, params: { selected_profile_id: @company.id }
    patch invitation_path(token: invitation.token), params: { profile_id: @person.id }
    assert_response :not_found
    assert_nil invitation.reload.accepted_at
    get invitation_path(token: invitation.token)
    assert_select "input[name=profile_id][value='#{@company.id}']"
    patch invitation_path(token: invitation.token), params: { profile_id: @company.id }
    assert_equal [ @company.id ], entry.reload.collaborator_ids
    assert invitation.reload.accepted_at
  end

  test "company accounts can add a personal profile and deleting an account unlinks every profile" do
    account = @other.account
    personal = make_profile("person", account)
    assert_equal personal.id, account.reload.submission.id
    second_company = make_profile("organisation", account)
    account.destroy!
    assert_nil @other.reload.account_id
    assert_nil personal.reload.account_id
    assert_nil second_company.reload.account_id
  end
end
