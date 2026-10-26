require "test_helper"

class ChallengesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = profile("owner@example.test")
    @other = profile("other@example.test")
    @attributes = { title: "Make local food affordable", description: "Families need affordable fresh food.", location: "Bristol",
      objectives: "Open a weekly community stall", industry: ProfileOptions::SECTORS.first, target_ids: [ "2.1" ],
      help_options: [ "Private funding", "Hiring" ], status: "active" }
  end

  def profile(email, **attributes)
    Submission.create!({ kind: "person", profile_version: 2, name: email.split("@").first.capitalize, email: email,
      purpose: "Local communities", experience: "Community work", consent: "1", location: "Bristol" }.merge(attributes))
  end

  def login(owner = @owner)
    post login_path, params: { email: owner.email }
    code = ActionMailer::Base.deliveries.last.body.decoded[/^(\d{6})$/, 1]
    post verify_login_path, params: { code: code }
  end

  test "project owner can select another public company without transferring ownership" do
    company = profile("company@example.test", kind: "organisation", organisation_name: "Community Kitchen", mission: "Food", offering: "Meals", challenge: "Access", challenge_kind: "Challenges")
    hidden = profile("hidden@example.test", kind: "organisation", organisation_name: "Private Kitchen", mission: "Food", offering: "Meals", challenge: "Access", challenge_kind: "Challenges", published: false)
    login
    get new_challenge_path
    assert_select "select[name='challenge[organisation_id]'] option[value='#{company.id}']", text: "Community Kitchen · Bristol"
    assert_select "select[name='challenge[organisation_id]'] option[value='#{hidden.id}']", count: 0
    assert_select "input[name='challenge[organisation_name]']"
    post challenges_path, params: { challenge: @attributes.merge(organisation_id: company.id) }
    entry = @owner.challenges.last
    assert_redirected_to challenge_path(entry)
    assert_equal @owner.id, entry.submission_id
    assert_equal company.id, entry.organisation_id
    assert_equal "Community Kitchen", entry.organisation_name
    get challenge_path(entry)
    assert_select ".project-organisation a[href='#{profile_path(company.public_slug)}']", text: "Community Kitchen"
    get profile_path(@owner.public_slug)
    assert_select ".challenge-card .project-organisation", text: /On behalf of Community Kitchen/
    company.update!(published: false)
    get challenge_path(entry)
    assert_select ".project-organisation", text: /Community Kitchen/
    assert_select ".project-organisation a", count: 0
    patch challenge_path(entry), params: { challenge: { title: "Updated project" } }
    assert_response :see_other
    company.destroy!
    assert_nil entry.reload.organisation_id
    assert_equal "Community Kitchen", entry.organisation_name
  end

  test "owners can add a company name change it or clear it without creating a profile" do
    login
    assert_no_difference "Submission.count" do
      post challenges_path, params: { challenge: @attributes.merge(organisation_name: "  New co-operative  ") }
    end
    entry = @owner.challenges.last
    assert_equal "New co-operative", entry.organisation_name
    assert_nil entry.organisation_id
    get challenge_path(entry)
    assert_select ".project-organisation", text: /On behalf of New co-operative/
    assert_select ".project-organisation a", count: 0
    patch challenge_path(entry), params: { challenge: { organisation_id: "", organisation_name: "Different company" } }
    assert_equal "Different company", entry.reload.organisation_name
    patch challenge_path(entry), params: { challenge: { organisation_id: "", organisation_name: "" } }
    assert_response :see_other
    get challenge_path(entry)
    assert_select ".project-organisation", count: 0
  end

  test "company selection rejects private profiles people and missing records" do
    hidden = profile("hidden@example.test", kind: "organisation", organisation_name: "Private Kitchen", mission: "Food", offering: "Meals", challenge: "Access", challenge_kind: "Challenges", published: false)
    login
    [ hidden.id, @other.id, 999999 ].each do |id|
      assert_no_difference "Challenge.count" do
        post challenges_path, params: { challenge: @attributes.merge(organisation_id: id) }
      end
      assert_response :unprocessable_entity
      assert_select ".error-summary", text: /must be a public company profile/
      assert_select "select[name='challenge[organisation_id]'] option[value='#{hidden.id}']", count: 0
      assert_no_match "Private Kitchen", response.body
    end
  end

  test "project URLs are canonical for links forms and invitations" do
    login
    assert_equal "/projects", challenges_path
    assert_equal "/projects/new", new_challenge_path
    entry = @owner.challenges.create!(@attributes)
    assert_equal "/projects/#{entry.id}", challenge_path(entry)
    assert_equal "/projects/#{entry.id}/edit", edit_challenge_path(entry)
    assert_equal "/projects/#{entry.id}/collaborator_invitations", challenge_collaborator_invitations_path(entry)

    get "/projects"
    assert_response :success
    assert_select "a[href='/projects/#{entry.id}']"
    assert_select "a[href='/projects/new']"
    login
    get "/projects/new"
    assert_response :success
    assert_select "form[action='/projects'][method='post']"
    get "/projects/#{entry.id}/edit"
    assert_response :success
    assert_select "form[action='/projects/#{entry.id}']"
  end

  test "old challenge links redirect permanently preserving paths and search filters" do
    [ "", "/new", "/123", "/123/edit", "/123/collaborator_invitations",
      "?q=food%20waste&location=Bristol&page=2", "/new?submission_id=9" ].each do |suffix|
      get "/challenges#{suffix}"
      assert_response :moved_permanently
      assert_redirected_to "/projects#{suffix}"
    end
  end

  test "owners draft publish complete and start another challenge without changing their portfolio" do
    @owner.update!(projects: [ { "title" => "Existing work", "role" => "Designer", "problem" => "Access", "context" => "Local", "approach" => "Research", "results" => "A guide" } ])
    original_projects = @owner.projects
    login
    get new_challenge_path
    assert_response :success
    assert_select "option[value='active']"
    post challenges_path, params: { challenge: { title: "Draft work", status: "draft" } }
    entry = @owner.challenges.last
    assert entry
    assert_nil entry.published_at
    assert_redirected_to challenge_path(entry)
    get challenge_path(entry)
    assert_response :success
    assert_select ".notice", text: /Only you/
    patch challenge_path(entry), params: { challenge: @attributes.merge(collaborator_ids: [ @other.id.to_s ]) }
    assert_redirected_to challenge_path(entry)
    assert entry.reload.published_at
    get root_path
    assert_select ".recent-work a[href='#{challenge_path(entry)}']"
    get profile_path(@owner.public_slug)
    assert_select ".current-challenge a[href='#{challenge_path(entry)}']"
    post challenges_path, params: { challenge: @attributes.merge(title: "Next challenge") }
    assert_response :unprocessable_entity
    assert_equal 1, @owner.challenges.where(status: "active").count
    patch challenge_path(entry), params: { challenge: { status: "completed" } }
    assert_response :unprocessable_entity
    assert_equal "active", entry.reload.status
    patch challenge_path(entry), params: { challenge: { status: "completed", project_role: "Organiser", context: "Local food costs",
      approach: "Worked with growers", results: "Opened the stall" } }
    assert_redirected_to challenge_path(entry)
    assert entry.reload.completed_at
    assert_equal original_projects, @owner.reload.projects
    get profile_path(@owner.public_slug)
    assert_select "#projects h2", text: "Projects"
    get challenge_path(entry)
    assert_select "h2", text: "Results & what changed"
    assert_select "a[href='#{profile_path(@other.public_slug)}']", text: @other.display_name
    assert_select "a", text: "Get involved", count: 0
    post challenges_path, params: { challenge: @attributes.merge(title: "The next project") }
    assert_response :see_other
    assert_equal "completed", entry.reload.status
    assert_equal 1, @owner.challenges.where(status: "active").count
  end

  test "drafts private owners and other accounts cannot leak or edit challenges" do
    private_entry = @owner.challenges.create!(@attributes.merge(status: "draft"))
    get challenge_path(private_entry)
    assert_response :not_found
    get new_challenge_path
    assert_redirected_to login_path
    login(@other)
    [ challenge_path(private_entry), edit_challenge_path(private_entry) ].each do |path|
      get path
      assert_response :not_found
    end
    patch challenge_path(private_entry), params: { challenge: { title: "Stolen", status: "active" } }
    assert_response :not_found
    assert_equal @attributes[:title], private_entry.reload.title
    private_entry.update!(status: "active")
    @owner.update!(published: false)
    get challenge_path(private_entry)
    assert_response :not_found
    get challenges_path
    assert_select ".challenge-card", count: 0
    get root_path
    assert_select ".challenge-card", count: 0
    delete logout_path
    login
    get challenge_path(private_entry)
    assert_response :success
    assert_select ".notice", text: /Only you/
    assert_select "a", text: "Get involved", count: 0
  end

  test "signed in discovery combines location industry goal status and text" do
    login
    active = @owner.challenges.create!(@attributes)
    @other.challenges.create!(@attributes.merge(title: "Elsewhere", location: "London", status: "paused"))
    filters = { q: "food", location: "bristol", industry: @attributes[:industry], goal: "2", status: "active" }
    get challenges_path, params: filters
    assert_response :success
    assert_select ".challenge-card", count: 1
    assert_select "a[href='#{challenge_path(active)}']"
    get challenge_path(active)
    assert_response :success
    get challenges_path, params: filters.merge(goal: "3")
    assert_select ".challenge-card", count: 0
    get challenges_path(status: "draft")
    assert_select ".challenge-card", count: 1
  end

  test "pagination preserves challenge filters" do
    login
    25.times do |index|
      @owner.challenges.create!(@attributes.merge(title: "Food #{index}", status: "completed", project_role: "Organiser", context: "Food", approach: "Stalls", results: "Less waste"))
    end
    filters = { q: "food", location: "Bristol", industry: @attributes[:industry], goal: "2", status: "completed" }
    get challenges_path, params: filters
    assert_select ".challenge-card", count: 24
    assert_select "a[href='#{challenges_path(filters.merge(page: 2))}']", text: "Next"
    get challenges_path, params: filters.merge(page: 2)
    assert_select ".challenge-card", count: 1
  end

  test "get involved stores challenge context and rejects forged or closed challenges" do
    entry = @owner.challenges.create!(@attributes)
    other_entry = @other.challenges.create!(@attributes)
    get new_profile_contact_path(@owner.public_slug, challenge_id: entry.id)
    assert_response :success
    assert_select "input[type=hidden][name=challenge_id][value='#{entry.id}']"
    assert_no_match @owner.email, response.body
    request = { name: "Helper", email: "helper@example.test", message: "I can help with hiring", intent: "problem", consent: "1" }
    post profile_contact_path(@owner.public_slug), params: { challenge_id: entry.id, contact_request: request.merge(challenge_id: other_entry.id) }
    assert_response :see_other
    assert_equal entry.id, ContactRequest.last.challenge_id
    assert_equal @owner.id, ContactRequest.last.submission_id
    assert_no_difference "ContactRequest.count" do
      post profile_contact_path(@owner.public_slug), params: { challenge_id: other_entry.id, contact_request: request }
    end
    assert_response :not_found
    entry.update!(status: "paused")
    get new_profile_contact_path(@owner.public_slug, challenge_id: entry.id)
    assert_response :not_found
  end

  test "organisations can publish and receive challenge requests" do
    company = profile("company@example.test", kind: "organisation", organisation_name: "Food Co-op", mission: "Less waste", offering: "Food", challenge_kind: "Goals", challenge: "Grow")
    entry = company.challenges.create!(@attributes)
    get challenge_path(entry)
    assert_response :success
    get new_profile_contact_path(company.public_slug, challenge_id: entry.id)
    assert_response :success
    assert_select "p", text: /Food Co-op/
  end

  test "invalid choices and private collaborator IDs fail while later unpublishing hides credits" do
    entry = @owner.challenges.build(@attributes)
    entry.help_options = [ "Unapproved option" ]
    assert_not entry.valid?
    entry.help_options = []
    entry.collaborator_ids = [ @owner.id ]
    assert_not entry.valid?
    @other.update!(published: false)
    entry.collaborator_ids = [ @other.id ]
    assert_not entry.valid?
    @other.update!(published: true)
    entry.save!
    @other.update!(published: false)
    get challenge_path(entry)
    assert_select "a[href='#{profile_path(@other.public_slug)}']", count: 0
    entry.update!(objectives: "Updated objectives")
    assert_empty entry.collaborators
  end

  test "pausing does not claim completion and drafts never enter public profiles" do
    entry = @owner.challenges.create!(@attributes)
    entry.update!(status: "paused")
    assert_nil entry.completed_at
    @owner.challenges.create!(@attributes.merge(title: "Secret draft", status: "draft"))
    get profile_path(@owner.public_slug)
    assert_select "summary", text: "Previous projects"
    assert_select "a[href='#{challenge_path(entry)}']"
    assert_no_match "Secret draft", response.body
    get challenges_path
    assert_select ".challenge-card", count: 0
  end
  test "project website links reject unsafe schemes even for invalid stored data" do
    entry = @owner.challenges.create!(@attributes.merge(status: "completed", project_role: "Organiser", context: "Food", approach: "Stalls", results: "Less waste"))
    [ "javascript:alert(1)", "data:text/html,hello", "https://", "https://user:password@example.test" ].each do |url|
      entry.project_url = url
      assert_not entry.valid?
      assert_nil entry.validated_project_url
      entry.update_column(:project_url, url)
      get challenge_path(entry)
      assert_response :success
      assert_select "a", text: "Visit the project website", count: 0
    end
    entry.update!(project_url: "https://example.test/work?year=2026")
    get challenge_path(entry)
    assert_select "a[href='https://example.test/work?year=2026']", text: "Visit the project website"
  end

  test "the database enforces a single active challenge even without model validation" do
    @owner.challenges.create!(@attributes)
    draft = @owner.challenges.create!(@attributes.merge(status: "draft"))
    assert_raises(ActiveRecord::RecordNotUnique) { draft.update_column(:status, "active") }
  end

  test "collaborator search is authenticated bounded and only returns matching public profiles" do
    get collaborator_search_challenges_path, params: { submission_id: @owner.id, collaborator_query: "Other" }
    assert_redirected_to login_path
    login
    profile("secret-search@example.test", name: "Other private", published: false)
    11.times { |i| profile("search-#{i}@example.test", name: "Matching member #{i}") }
    get new_challenge_path
    assert_select "#collaborator-selection input[type=checkbox]", count: 0
    assert_select "#collaborator-selection", text: /No collaborators selected yet/
    [ "", "O" ].each do |query|
      get collaborator_search_challenges_path, params: { submission_id: @owner.id, collaborator_query: query }
      assert_equal [], response.parsed_body
    end
    get collaborator_search_challenges_path, params: { submission_id: @owner.id, collaborator_query: "Other" }
    assert_equal [ { "id" => @other.id, "name" => @other.display_name, "location" => @other.location } ], response.parsed_body
    assert_equal "no-store", response.headers["Cache-Control"]
    get collaborator_search_challenges_path, params: { submission_id: @owner.id, collaborator_query: "Matching" }
    assert_equal 10, response.parsed_body.size
    get collaborator_search_challenges_path, params: { submission_id: @owner.id, collaborator_query: "%_" }
    assert_empty response.parsed_body
    get collaborator_search_challenges_path, params: { submission_id: @other.id, collaborator_query: "Matching" }
    assert_response :not_found
  end

  test "search without JavaScript preserves project edits and selections without saving" do
    login
    entry = @owner.challenges.create!(@attributes)
    patch challenge_path(entry), params: { search_collaborators: "1", collaborator_query: "Other", challenge: { title: "Unsaved title", collaborator_ids: [ "" ] } }
    assert_response :success
    assert_equal @attributes[:title], entry.reload.title
    assert_select "input[name='challenge[title]'][value='Unsaved title']"
    assert_select "#collaborator-results #challenge_collaborator_#{@other.id}"
    patch challenge_path(entry), params: { search_collaborators: "1", collaborator_query: "Nobody", challenge: { title: "Unsaved title", collaborator_ids: [ "", @other.id.to_s ] } }
    assert_select "[data-selected-collaborators] #challenge_collaborator_#{@other.id}[checked]"
    assert_empty entry.reload.collaborator_ids
    assert_no_difference "Challenge.count" do
      post challenges_path, params: { search_collaborators: "1", collaborator_query: "Other", challenge: { title: "Unfinished draft", status: "draft" } }
    end
    assert_response :success
    assert_select "input[name='challenge[title]'][value='Unfinished draft']"
  end

  test "collaborator checkboxes can remove one member or clear everyone" do
    third = profile("third@example.test")
    entry = @owner.challenges.create!(@attributes.merge(collaborator_ids: [ @other.id, third.id ]))
    login
    get edit_challenge_path(entry)
    assert_select "select[multiple][name='challenge[collaborator_ids][]']", count: 0
    assert_select "input[type=hidden][name='challenge[collaborator_ids][]'][value='']"
    assert_select "#challenge_collaborator_#{@other.id}[checked]"
    assert_select "#challenge_collaborator_#{third.id}[checked]"
    assert_select "form form", count: 0
    assert_select "#email-invitations form[action='#{challenge_collaborator_invitations_path(entry)}'] input[type=email]"
    patch challenge_path(entry), params: { challenge: { collaborator_ids: [ "", third.id.to_s ] } }
    assert_response :see_other
    assert_equal [ third.id.to_s ], entry.reload.collaborator_ids
    patch challenge_path(entry), params: { challenge: { collaborator_ids: [ "" ] } }
    assert_response :see_other
    assert_empty entry.reload.collaborator_ids
  end

  test "owner can remove a collaborator directly but other accounts cannot" do
    entry = @owner.challenges.create!(@attributes.merge(collaborator_ids: [ @other.id ]))
    login(@other)
    get challenge_path(entry)
    assert_select "#collaborators a[href='#{profile_path(@other.public_slug)}']"
    assert_select "#collaborators form", count: 0
    delete challenge_collaborator_path(entry, @other.id)
    assert_response :not_found
    assert_equal [ @other.id ], entry.reload.collaborator_ids
    delete logout_path
    delete challenge_collaborator_path(entry, @other.id)
    assert_redirected_to login_path
    login
    get challenge_path(entry)
    assert_select "#collaborators button[aria-label='Remove #{@other.display_name} from this project']"
    assert_select "#collaborators input[type=email]"
    delete challenge_collaborator_path(entry, @other.id)
    assert_redirected_to challenge_path(entry, anchor: "collaborators")
    assert_empty entry.reload.collaborator_ids
    delete challenge_collaborator_path(entry, @other.id)
    assert_response :not_found
  end

  test "unpublished existing collaborators can be removed without exposing unrelated private profiles" do
    entry = @owner.challenges.create!(@attributes.merge(collaborator_ids: [ @other.id ]))
    @other.update!(published: false)
    secret = profile("secret@example.test", published: false)
    login
    get edit_challenge_path(entry)
    assert_select "#challenge_collaborator_#{@other.id}[checked]"
    assert_select "#challenge_collaborator_#{secret.id}", count: 0
    patch challenge_path(entry), params: { challenge: { collaborator_ids: [ secret.id.to_s ] } }
    assert_response :unprocessable_entity
    assert_select "#challenge_collaborator_#{secret.id}", count: 0
    assert_equal [ @other.id ], entry.reload.collaborator_ids
    delete challenge_collaborator_path(entry, @other.id)
    assert_response :see_other
    assert_empty entry.reload.collaborator_ids
  end
end
