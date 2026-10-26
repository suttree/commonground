require "test_helper"

class DiscoveryAccessTest < ActionDispatch::IntegrationTest
  setup do
    @person = Submission.create!(kind: "person", profile_version: 2, name: "Public person", email: "person@example.test",
      purpose: "Useful work", experience: "Projects", consent: "1")
    @company = Submission.create!(kind: "organisation", profile_version: 2, name: "Company owner", organisation_name: "Public company",
      email: "company@example.test", purpose: "Useful work", mission: "Help", offering: "Services", challenge_kind: "Goals", challenge: "Grow", consent: "1")
    @project = @person.challenges.create!(title: "Public project", description: "Useful work", objectives: "Help", location: "Bristol", status: "active")
  end

  test "visitors see directory signup pages without listings counts or pagination" do
    [ [ people_path, @person.display_name ], [ companies_path, @company.display_name ], [ challenges_path, @project.title ] ].each do |path, name|
      get path
      assert_response :success
      assert_not_includes response.body, name
      assert_select ".directory-card, .challenge-card, [role=status], nav[aria-label='Directory pages'], nav[aria-label='Project pages']", count: 0
      assert_select "form.directory-filters", count: 0
      assert_select ".discovery-signup a[href='#{join_path}']", text: "Sign up"
      assert_select ".discovery-signup a[href='#{login_path}']", text: "Log in"
      get path, params: { page: 2, q: "", location: "" }
      assert_response :success
      assert_select ".directory-card, .challenge-card, [role=status]", count: 0
    end
    [ profile_path(@person.public_slug), profile_path(@company.public_slug), challenge_path(@project) ].each do |path|
      get path
      assert_response :success
    end
  end

  test "every supported search filter requires an account even in a direct URL" do
    { people_path => %i[q location skill sector goal target priorities],
      companies_path => %i[q location skill sector goal target priorities],
      challenges_path => %i[q location industry goal status] }.each do |path, keys|
      keys.each do |key|
        get path, params: { key => "1" }
        assert_redirected_to join_path
        assert_equal "no-store", response.headers["Cache-Control"]
      end
    end
    follow_redirect!
    assert_response :success
    assert_select ".notice", text: /Create an account or log in to search/
  end

  test "signed in members can search all directories and logout removes search access" do
    sign_in_account(Account.create!(email: "member@example.test"))
    [ people_path, companies_path, challenges_path ].each do |path|
      get path, params: { q: "Public" }
      assert_response :success
      assert_select "form.directory-filters"
      assert_select ".directory-card, .challenge-card", count: 1
      assert_select ".discovery-signup", count: 0
    end
    delete logout_path
    get people_path(q: "Public")
    assert_redirected_to join_path
  end
end
