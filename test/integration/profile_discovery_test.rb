require "test_helper"

class ProfileDiscoveryTest < ActionDispatch::IntegrationTest
  def profile(**attributes)
    Submission.create!({ kind: "person", profile_version: 2, name: "Alex", email: "alex@example.test",
      purpose: "Local communities", experience: "Community work", consent: "1", location: "Bristol",
      sectors_past: [ ProfileOptions::SECTORS.first ], target_ids: [ "11.2" ], sector_reason: "Make streets accessible",
      skills: [ { "skill" => "Research", "organisation" => "Co-op", "time" => "2026", "results" => "Better routes" } ] }.merge(attributes))
  end

  test "skill discovery combines filters and cards show a useful introduction" do
    sign_in_account(Account.create!(email: "searcher@example.test"))
    owner = profile
    profile(email: "hidden@example.test", published: false)
    get people_path, params: { skill: "research", location: "bristol", sector: ProfileOptions::SECTORS.first, goal: "11", target: "11.2" }
    assert_select ".directory-card", count: 1
    assert_select ".directory-card", text: /Make streets accessible/
    assert_select ".directory-location", text: "Bristol"
    get people_path(skill: "Unmatched")
    assert_select ".directory-card", count: 0
    get people_path
    assert_select ".directory-card", text: /#{Regexp.escape(ProfileOptions::SECTORS.first)}/, count: 0
    get profile_path(owner.public_slug)
    assert_select "a[href='#{people_path(skill: 'Research')}']", text: "Research"
    assert_select "a[href='#{profile_skill_path(owner.public_slug, 1)}']", text: /Read more/
    owner.update!(sector_reason: "")
    get people_path
    assert_select ".directory-card", text: /Local communities/
  end

  test "contact buttons require an explicit public destination" do
    owner = profile
    get profile_path(owner.public_slug)
    assert_no_match "mailto:", response.body
    assert_not owner.update(contact_action: "Follow me", contact_destination: "javascript:alert(1)")
    assert_not owner.update(contact_action: "Connect on LinkedIn", contact_destination: "https://linkedin.com.evil.test/me")
    owner.update!(contact_action: "Email me", contact_destination: "public@example.test")
    get profile_path(owner.public_slug)
    assert_select "a[href='mailto:public@example.test']", text: "Email me"
    assert_no_match owner.email, response.body
  end

  test "signed in navigation and manually selected priorities have useful next steps" do
    owner = profile
    post login_path, params: { email: owner.email }
    code = ActionMailer::Base.deliveries.last.body.decoded[/code is (\d{6})/, 1]
    post verify_login_path, params: { code: code }
    get dashboard_path
    assert_select "a.wordmark[href='#{dashboard_path}']"
    assert_select "nav form[action='#{logout_path}'] button", text: "Log out"
    assert_select "h2", text: "Your current priorities"
    assert_select "a", text: "Take the eight-question SDG quiz", count: 0
    delete logout_path
    get root_path
    assert_select "a.wordmark[href='#{root_path}']"
    assert_select "a[href='#{people_path}']", text: /Find a collaborator/
    assert_select "a[href='#{new_person_path}']", text: /Create a profile/
  end
end
