require "test_helper"

class MemberDashboardTest < ActionDispatch::IntegrationTest
  setup do
    @member = profile("member@example.test", target_ids: [ "7.2" ])
  end

  def profile(email, **attributes)
    Submission.create!({ kind: "person", profile_version: 2, name: email.split("@").first.capitalize, email: email,
      purpose: "Local communities", experience: "Community work", consent: "1", location: "Bristol" }.merge(attributes))
  end

  def login(owner = @member)
    post login_path, params: { email: owner.email }
    code = ActionMailer::Base.deliveries.last.body.decoded[/^(\d{6})$/, 1]
    post verify_login_path, params: { code: code }
  end

  def publish_challenge(owner, title, published_at:, target_ids: [ "7.2" ])
    owner.challenges.create!(title: title, description: "What needs doing.", location: "Bristol", objectives: "Do it",
      target_ids: target_ids, status: "active").tap { |challenge| challenge.update_columns(published_at: published_at) }
  end

  test "availability distinguishes not provided from not available and is editable from the dashboard" do
    login
    get dashboard_path
    assert_select ".dashboard-availability.is-missing", text: /Not provided yet/
    assert_select ".dashboard-availability a[href='#{edit_account_profile_path(section: 'availability', profile_id: @member.id)}']"
    get profile_path(@member.public_slug)
    assert_select ".member-availability", count: 0
    assert_select ".owner-note a", text: "add your availability"

    get edit_account_profile_path(section: "availability", profile_id: @member.id)
    assert_select "#availability-hint", text: /public profile/
    patch account_profile_path, params: { profile_id: @member.id, section: "availability", submission: { availability_status: "limited", availability_hours: "8", availability_note: "From March" } }
    assert_redirected_to edit_account_profile_path(section: "availability", profile_id: @member.id)
    assert_equal "Limited availability, about 8 hours a week", @member.reload.availability_summary

    patch account_profile_path, params: { profile_id: @member.id, section: "availability", submission: { availability_status: "unavailable", availability_hours: "8" } }
    assert_nil @member.reload.availability_hours
    delete logout_path
    get profile_path(@member.public_slug)
    assert_select ".member-availability.availability-unavailable", text: "Not available right now"
    assert_select ".owner-note", count: 0

    login
    patch account_profile_path, params: { profile_id: @member.id, section: "availability", submission: { availability_status: "sometimes" } }
    assert_response :unprocessable_entity
    patch account_profile_path, params: { profile_id: @member.id, section: "availability", submission: { availability_status: "" } }
    assert_not @member.reload.availability_provided?
  end

  test "dashboard puts current work first and adapts actions to an active project" do
    login
    get dashboard_path
    assert_select ".dashboard-current-work", text: /don’t have an active project/
    assert_select ".dashboard-current-work a.button[href='#{new_challenge_path}']", text: "Start a project"
    assert_select ".dashboard-now + .dashboard-next-steps + .dashboard-reflection"

    challenge = publish_challenge(@member, "Community energy", published_at: 1.day.ago)
    get dashboard_path
    assert_select ".dashboard-current-work h3 a[href='#{challenge_path(challenge)}']", text: "Community energy"
    assert_select ".dashboard-current-work a.button[href='#{edit_challenge_path(challenge)}']", text: "Update your project"
    assert_select ".dashboard-current-work a[href='#{edit_challenge_path(challenge, anchor: 'challenge_status')}']", text: "Mark it completed"
    assert_select ".dashboard-next-steps a[href='#{new_challenge_path}']", count: 0
    assert_select ".dashboard-next-steps a[href='#{challenge_collaborator_invitations_path(challenge)}']"
  end

  test "goal projects are ordered by publication date with an empty state" do
    login
    get dashboard_path
    assert_select ".dashboard-goal-projects .sdg-color-7", text: /Goal 7/
    assert_select ".dashboard-goal-projects .empty-state"

    other = profile("other@example.test")
    older = publish_challenge(other, "Older but edited", published_at: 3.days.ago)
    newer = publish_challenge(profile("third@example.test"), "Newer", published_at: 1.day.ago)
    publish_challenge(profile("fourth@example.test"), "Water", published_at: 1.hour.ago, target_ids: [ "6.1" ])
    older.touch
    get dashboard_path
    assert_select ".dashboard-goal-projects .challenge-card h3" do |titles|
      assert_equal [ newer.title, older.title ], titles.map { |title| title.text.strip }
    end

    get sdg_goal_path(7)
    assert_select "#goal-projects .challenge-card h3", count: 2
    get sdg_goal_path(6)
    assert_select "#goal-projects .challenge-card h3", text: "Water"
    get sdg_goal_path(1)
    assert_select "#goal-projects .empty-state", text: /No published projects/
  end

  test "sparse profiles hide empty sections and use initials" do
    sparse = profile("sparse@example.test", name: "Ada Lovelace", location: "", experience: "x")
    sparse.update_columns(purpose: "")
    get profile_path(sparse.public_slug)
    assert_response :success
    assert_select ".member-identity span", text: "AL"
    assert_select ".member-intro, .member-current, .member-aside, .member-facts", count: 0
  end
end
