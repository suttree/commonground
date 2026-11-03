require "test_helper"

class EditorialProfileEditorTest < ActionDispatch::IntegrationTest
  setup do
    @account = Account.create!(email: "editorial@example.test")
    @profile = Submission.create!(account: @account, kind: "person", profile_version: 2, name: "Alex", email: @account.email,
      purpose: "Help communities", experience: "Community work", consent: "1", location: "Haarlem, Netherlands")
    post login_path, params: { email: @account.email }
    post verify_login_path, params: { code: ActionMailer::Base.deliveries.last.body.decoded[/^(\d{6})$/, 1] }
  end

  test "grouped editor retains every section and only suggests public locations" do
    hidden = Submission.create!(kind: "person", profile_version: 2, name: "Hidden", email: "hidden@example.test", purpose: "Help", experience: "Work", consent: "1", published: false, location: "Private location")
    ProfileSections::EDITORIAL.each do |key, (label, _)|
      get edit_account_profile_path(section: key)
      assert_response :success
      assert_select ".story-nav a", count: 4
      assert_select "h2", text: label
      assert_select "[data-save-label]", count: 2
    end
    get edit_account_profile_path
    assert_select "#profile-locations option[value='Haarlem, Netherlands']"
    assert_select "#profile-locations option[value='#{hidden.location}']", count: 0
    assert_select ".story-photo-frame input[type=file]"
    assert_select "input[name='submission[email]']", count: 0
    assert_select "textarea[name='submission[purpose]'][placeholder]"
  end

  test "saves groups independently and only continues after a successful save" do
    patch account_profile_path, params: { section: "identity", next_section: "future", submission: { name: "", purpose: "Updated purpose" } }
    assert_response :unprocessable_entity
    assert_select "form[data-unsaved=true]"
    assert_select "input[name=section][value=identity]"
    assert_equal "Help communities", @profile.reload.purpose
    patch account_profile_path, params: { section: "identity", next_section: "future", submission: { name: "Alex", purpose: "Updated purpose", contribution: "Injected" } }
    assert_redirected_to edit_account_profile_path(section: "future", profile_id: @profile.id)
    assert_nil @profile.reload.contribution
    follow_redirect!
    assert_select "[data-save-label]", text: "You, at a glance saved.", count: 2
    patch account_profile_path, params: { section: "future", next_section: "https://evil.example", submission: { availability_status: "Available for occasional help", contribution: "Build local communities", collaboration_interest: "Local organisers" } }
    assert_redirected_to edit_account_profile_path(section: "future", profile_id: @profile.id)
    patch account_profile_path, params: { section: "present", submission: { current_focus: "Opening a repair space", experience: "Injected" } }
    assert_equal "Community work", @profile.reload.experience
    get profile_path(@profile.public_slug)
    assert_select "section", text: /Opening a repair space/
    assert_select "section", text: /Build local communities/
    assert_select "section", text: /Local organisers/
    assert_select ".availability-dot.is-open"
    assert_no_match @account.email, response.body
  end

  test "past group stages repeated entries and saves portfolio images without touching identity" do
    skill = ProfileOptions::REPEATED_FIELDS.fetch("skills").keys.to_h { |key| [ key, "Research" ] }
    patch account_profile_path, params: { section: "past", add_section: "skills", submission: { skills: [ skill ] } }
    assert_response :success
    assert_empty @profile.reload.profile_entries("skills")
    assert_select "form[data-unsaved=true]"
    patch account_profile_path, params: { section: "past", submission: { skills: [ skill ], name: "Injected" } }
    assert_equal [ skill ], @profile.reload.skills
    assert_equal "Alex", @profile.name
    image = PortfolioImage.create!(submission: @profile, upload_owner: "test", content_type: "image/png", data: "saved image")
    project = { "title" => "Project", "role" => "Designer", "problem" => "Waste", "context" => "Local", "approach" => "Research", "results" => "Less waste", "image_id" => image.id }
    @profile.update!(projects: [ project ])
    patch account_profile_path, params: { section: "past", submission: { projects: [ project.merge("remove_image" => "1") ] } }
    assert_response :redirect
    assert_not PortfolioImage.exists?(image.id)
  end
end
