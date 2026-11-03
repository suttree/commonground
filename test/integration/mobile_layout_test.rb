require "test_helper"

class MobileLayoutTest < ActionDispatch::IntegrationTest
  def profile(**attributes)
    Submission.create!({ kind: "person", profile_version: 2, name: "Alex", email: "alex@example.test",
      purpose: "Local communities", experience: "Community work", consent: "1", location: "Bristol",
      sectors_past: [ ProfileOptions::SECTORS.first ], target_ids: [ "11.2" ], sector_reason: "Make streets accessible" }.merge(attributes))
  end

  test "signed in pages have a menu button that controls both link groups" do
    owner = profile
    sign_in_account(Account.create!(email: owner.email))
    get dashboard_path
    assert_select "body.app-page"
    assert_select "button.nav-toggle[aria-controls='site-menu'][aria-expanded='false'][hidden]"
    assert_select "#site-menu nav[aria-label='Main navigation'] a.nav-menu-only[href='#{dashboard_path}']", text: "Dashboard"
    assert_select "#site-menu nav[aria-label='Account'] a.nav-account[href='#{edit_account_profile_path}']"
    assert_select "script[src*='site_menu']"
    get root_path
    assert_select "body.app-page", count: 0
  end

  test "discovery filters sit in a sheet with a count, apply and clear actions" do
    sign_in_account(Account.create!(email: "searcher@example.test"))
    profile
    get people_path, params: { q: "Alex", location: "bristol", sector: ProfileOptions::SECTORS.first }
    assert_select "input#q[type=search][form='directory-filters']"
    assert_select "button[data-filter-open][aria-controls='filter-sheet']", text: /Filters\s+2/
    assert_select "dialog#filter-sheet[open] .directory-filters select#sector[form='directory-filters']"
    assert_select "dialog#filter-sheet button.filter-apply[form='directory-filters']", text: "Apply filters"
    assert_select "dialog#filter-sheet a.filter-clear[href='#{people_path}']"
    assert_select "dialog#filter-sheet button[data-filter-close][aria-label='Close filters']"
    assert_select ".applied-filters a", count: 3

    get challenges_path, params: { status: "completed", location: "Nowhere" }
    assert_select "button[data-filter-open]", text: /Filters\s+2/
    assert_select ".empty-state a[href='#{challenges_path}']", text: "Clear all filters"

    get companies_path
    assert_select "button[data-filter-open] .filter-count", count: 0
    assert_select ".empty-state a[href='#{challenges_path}']", text: "Browse projects"
  end

  test "profile button errors appear beside their fields and keep what was typed" do
    owner = profile
    sign_in_account(Account.create!(email: owner.email))
    patch account_profile_path, params: { profile_id: owner.id, section: "contact", submission: { contact_action: "Connect on LinkedIn", contact_destination: "https://example.test/me" } }
    assert_response :unprocessable_entity
    assert_select "input#submission_contact_destination[value='https://example.test/me'][aria-invalid='true'][aria-describedby='contact_destination-hint contact_destination-error']"
    assert_select "p.field-error#contact_destination-error"
    assert_select ".error-summary a[href='#submission_contact_destination']"
  end
end
