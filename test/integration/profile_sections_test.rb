require "test_helper"

class ProfileSectionsTest < ActionDispatch::IntegrationTest
  setup do
    @account = Account.create!(email: "sections@example.test")
    @profile = Submission.create!(account: @account, kind: "person", profile_version: 2, name: "Alex", email: @account.email,
      purpose: "Help communities", experience: "Community work", consent: "1", target_ids: [ "2.1" ],
      contact_action: "Follow me", contact_destination: "https://example.test")
    post login_path, params: { email: @account.email }
    code = ActionMailer::Base.deliveries.last.body.decoded[/code is (\d{6})/, 1]
    post verify_login_path, params: { code: code }
  end

  test "tabs show one section and successful saves stay on that section" do
    get edit_account_profile_path
    assert_select ".profile-tabs a", count: 8
    assert_select ".profile-tabs a[aria-current=page]", text: "Basics"
    assert_select "input[name='submission[name]']"
    assert_select "textarea[name='submission[purpose]']", count: 0
    assert_select "textarea[name*='projects']", count: 0
    assert_select "script[src*='profile_editor']"
    original = @profile.profile.deep_dup
    patch account_profile_path, params: { section: "basics", profile_id: @profile.id, submission: { name: "Alex updated", purpose: "Injected", target_ids: [], contact_destination: "https://wrong.test" } }
    assert_redirected_to edit_account_profile_path(section: "basics", profile_id: @profile.id)
    assert_equal "Alex updated", @profile.reload.name
    assert_equal "Help communities", @profile.purpose
    assert_equal original, @profile.profile
    follow_redirect!
    assert_select "[role=status]", text: "Basics saved."
  end

  test "both signup forms include one location field in basics" do
    delete logout_path
    [ new_person_path, new_organisation_path ].each do |path|
      get path
      assert_response :success
      assert_select "input[name='submission[location]']", count: 1
      assert_select "textarea[name='submission[location]']", count: 0
      assert_select "form fieldset:first-of-type input[name='submission[location]']"
    end
  end

  test "location saves from basics and can be found in the people directory" do
    get edit_account_profile_path
    assert_select "input[name='submission[location]']", count: 1
    patch account_profile_path, params: { section: "basics", profile_id: @profile.id, submission: { location: "Bristol, UK", radius_km: "25" } }
    assert_redirected_to edit_account_profile_path(section: "basics", profile_id: @profile.id)
    assert_equal "Bristol, UK", @profile.reload.location
    assert_equal "25", @profile.radius_km
    assert_equal "Help communities", @profile.purpose
    get people_path(location: "Bristol")
    assert_select ".directory-card h2", text: "Alex"
  end

  test "each personal tab renders and invalid sections are rejected" do
    ProfileSections::PERSONAL.each do |key, (label, _fields)|
      get edit_account_profile_path(section: key)
      assert_response :success
      assert_select "h2#profile-section-title", text: label
      assert_select "input[name=section][value='#{key}']"
    end
    [ "offering", "../../admin", "unknown" ].each do |key|
      get edit_account_profile_path(section: key)
      assert_response :not_found
      patch account_profile_path, params: { section: key, submission: { name: "No" } }
      assert_response :not_found
    end
    assert_equal "Alex", @profile.reload.name
  end

  test "validation retains the selected tab and submitted values" do
    patch account_profile_path, params: { section: "contact", submission: { contact_action: "Connect on LinkedIn", contact_destination: "https://example.test" } }
    assert_response :unprocessable_entity
    assert_select ".profile-tabs a[aria-current=page]", text: "Contact"
    assert_select "[role=alert]", text: /Contact destination/
    assert_select "input[name='submission[contact_destination]'][value='https://example.test']"
    assert_select "form[data-unsaved=true]"
    assert_equal "Follow me", @profile.reload.contact_action
    patch account_profile_path, params: { section: "contact", submission: { contact_action: "Connect on LinkedIn", contact_destination: "https://www.linkedin.com/company/example/" } }
    assert_redirected_to edit_account_profile_path(section: "contact", profile_id: @profile.id)
    assert_equal "Connect on LinkedIn", @profile.reload.contact_action
  end

  test "repeated entries stay on their tab without saving until requested" do
    skill = ProfileOptions::REPEATED_FIELDS.fetch("skills").keys.to_h { |key| [ key, "Research" ] }
    patch account_profile_path, params: { section: "skills", add_section: "skills", submission: { skills: [ skill ] } }
    assert_response :success
    assert_select ".profile-tabs a[aria-current=page]", text: "Skills"
    assert_select "fieldset.repeat-entry", count: 2
    assert_select "textarea", text: "Research"
    assert_empty @profile.reload.profile_entries("skills")
    patch account_profile_path, params: { section: "skills", submission: { skills: [ skill ] } }
    assert_redirected_to edit_account_profile_path(section: "skills", profile_id: @profile.id)
    assert_equal [ skill ], @profile.reload.skills
  end

  test "non-portfolio saves preserve images and cannot alter portfolio data" do
    image = PortfolioImage.create!(submission: @profile, upload_owner: "test", content_type: "image/png", data: "saved image")
    project = { "title" => "Project", "role" => "Designer", "problem" => "Waste", "context" => "Local", "approach" => "Research", "results" => "Less waste", "image_id" => image.id }
    @profile.update!(projects: [ project ])
    patch account_profile_path, params: { section: "purpose", submission: { purpose: "Updated purpose", projects: [ project.merge("remove_image" => "1") ] }, project_images: { "0" => "invalid upload" } }
    assert_redirected_to edit_account_profile_path(section: "purpose", profile_id: @profile.id)
    assert_equal [ project ], @profile.reload.projects
    assert PortfolioImage.exists?(image.id)
    patch account_profile_path, params: { section: "portfolio", submission: { projects: [ project.merge("remove_image" => "1") ] } }
    assert_redirected_to edit_account_profile_path(section: "portfolio", profile_id: @profile.id)
    assert_not PortfolioImage.exists?(image.id)
    assert_equal "Updated purpose", @profile.reload.purpose
  end

  test "company sections save independently without changing required fields elsewhere" do
    company = Submission.create!(account: @account, kind: "organisation", profile_version: 2, name: "Alex", email: @account.email,
      organisation_name: "Orchard", mission: "Food", purpose: "Community", offering: "Fruit", challenge_kind: "Goals", challenge: "Grow", consent: "1")
    patch switch_profile_path, params: { selected_profile_id: company.id }
    get edit_account_profile_path
    assert_select "input[name='submission[location]']", count: 1
    patch account_profile_path, params: { section: "basics", profile_id: company.id, submission: { location: "Bath, UK" } }
    assert_redirected_to edit_account_profile_path(section: "basics", profile_id: company.id)
    assert_equal "Bath, UK", company.reload.location
    get companies_path(location: "Bath")
    assert_select ".directory-card h2", text: "Orchard"

    ProfileSections::COMPANY.each do |key, (label, _fields)|
      get edit_account_profile_path(section: key)
      assert_response :success
      assert_select "h2#profile-section-title", text: label
      assert_select ".profile-tabs a", count: 7
    end
    patch account_profile_path, params: { section: "goals", profile_id: company.id, submission: { challenge_kind: "Goals", challenge: "Expand the orchard", help_needed: "Volunteers", mission: "Injected" } }
    assert_redirected_to edit_account_profile_path(section: "goals", profile_id: company.id)
    assert_equal "Expand the orchard", company.reload.challenge
    assert_equal "Food", company.mission
    patch account_profile_path, params: { section: "priorities", submission: { target_ids: [ "12.3" ], exploring: "0" } }
    assert_equal [ "12.3" ], company.reload.target_ids
    assert_equal "Expand the orchard", company.challenge
    assert_equal [ "2.1" ], @profile.reload.target_ids
  end
end
