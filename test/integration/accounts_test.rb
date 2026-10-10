require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  def profile(email: "owner@example.test", kind: "person", **attributes)
    Submission.create!({ kind: kind, profile_version: 2, name: "Alex", email: email,
      purpose: "Help communities", experience: "Community projects", consent: "1",
      organisation_name: "Orchard", mission: "Reduce waste", offering: "Food", challenge_kind: "Goals", challenge: "Grow" }.merge(attributes))
  end

  def login(email)
    post login_path, params: { email: email }
    assert_redirected_to verify_login_path
    code = ActionMailer::Base.deliveries.last.body.decoded[/code is (\d{6})/, 1]
    assert code
    post verify_login_path, params: { code: code }
    assert_redirected_to dashboard_path
  end

  test "verification claims only matching profiles and logout protects edits" do
    owned = profile
    other = profile(email: "other@example.test")
    get dashboard_path
    assert_redirected_to login_path
    patch account_profile_path, params: { submission: { name: "Changed" } }
    assert_redirected_to login_path
    login(" OWNER@example.test ")
    assert_equal "owner@example.test", owned.reload.account.email
    assert_nil other.reload.account_id
    get dashboard_path
    assert_response :success
    [ people_path, companies_path, sdgs_path, quiz_path, profile_path(owned.public_slug) ].each { |path| assert_select "a[href='#{path}']" }
    get dashboard_path(profile_id: other.id)
    assert_response :not_found
    delete logout_path
    get edit_account_profile_path
    assert_redirected_to login_path
  end

  test "profile edit preserves private fields and cannot change publication" do
    owned = profile(notes: "Private note")
    login(owned.email)
    get edit_account_profile_path
    assert_response :success
    assert_select "input[name='submission[published]']", count: 0
    patch account_profile_path, params: { submission: { name: "Updated", published: "1", email: "attacker@example.test", account_id: 1234, notes: "Injected", status: "Introduced" } }
    assert_redirected_to dashboard_path
    owned.reload
    assert_equal "Updated", owned.name
    assert_equal "owner@example.test", owned.email
    assert_equal "Private note", owned.notes
    assert_equal "Received", owned.status
    get profile_path(owned.public_slug)
    assert_response :success
    assert_no_match owned.email, response.body
    patch account_profile_path, params: { submission: { published: "0" } }
    assert owned.reload.published?
    get profile_path(owned.public_slug)
    assert_response :success
    delete logout_path
    get profile_path(owned.public_slug)
    assert_response :success
  end

  test "quiz saves to the single company profile" do
    company = profile(kind: "organisation")
    other = profile(email: "other@example.test")
    login(company.email)
    get dashboard_path
    assert_select ".eyebrow", text: "Company dashboard"
    8.times { |index| post quiz_path, params: { question: index, answer: "1" } }
    assert_nil company.reload.profile["quiz_answers"]
    post confirm_quiz_path, params: { target_ids: SdgQuiz.matches((0..7).to_h { |index| [ index.to_s, "1" ] }).keys }
    assert_equal 8, company.reload.profile.fetch("quiz_answers").size
    assert_equal SdgQuiz.matches((0..7).to_h { |index| [ index.to_s, "1" ] }).keys, company.target_ids
    assert_nil other.reload.target_ids
    get quiz_path
    assert_select "p", text: /your answers stay private/
    company.update!(published: true)
    get profile_path(company.public_slug)
    assert_select "h2", text: "SDG quiz answers", count: 0
    assert_select ".profile-targets .eyebrow", text: "Sustainable development goals"
    assert_select "h2", text: "Problems I want to work on next"
  end

  test "failed codes do not log in" do
    post login_path, params: { email: "alex@example.test" }
    5.times do
      post verify_login_path, params: { code: "wrong" }
      assert_response :unprocessable_entity
    end
    code = ActionMailer::Base.deliveries.last.body.decoded[/code is (\d{6})/, 1]
    post verify_login_path, params: { code: code }
    assert_response :unprocessable_entity
    get dashboard_path
    assert_redirected_to login_path
  end

  test "both directories filter only public profiles" do
    person = profile(published: true, location: "Bristol", sectors_future: [ ProfileOptions::SECTORS.first ], target_ids: [ "12.3" ])
    profile(published: false, email: "private@example.test", name: "Secret", location: "Bristol")
    company = profile(kind: "organisation", published: true, location: "Bristol", sectors_past: [ ProfileOptions::SECTORS.first ], target_ids: [ "12.3" ])
    [ [ people_path, person ], [ companies_path, company ] ].each do |path, record|
      get path, params: { q: record.display_name, location: "bristol", sector: ProfileOptions::SECTORS.first, goal: "12" }
      assert_response :success
      assert_select ".directory-card", count: 1
      assert_select ".directory-card a[href='#{profile_path(record.public_slug)}']"
      assert_no_match "Secret", response.body
      assert_no_match record.email, response.body
      get path, params: { goal: "1" }
      assert_select ".directory-card", count: 0
    end
  end

  test "target searches match the exact selected target and keep other filters" do
    matching = profile(published: true, target_ids: [ "11.2" ], location: "Bristol")
    profile(email: "different@example.test", published: true, target_ids: [ "11.7" ])
    profile(published: false, email: "private@example.test", target_ids: [ "11.2" ])
    get people_path(target: "11.2", location: "Bristol")
    assert_response :success
    assert_select ".directory-card", count: 1
    assert_select ".directory-card a[href='#{profile_path(matching.public_slug)}']"
    assert_select "select[name=target] option[selected][value='11.2']"
    get people_path(target: "11.2", location: "London")
    assert_select ".directory-card", count: 0
  end

  test "company profile edits retain repeaters and apply sector and priority changes" do
    company = profile(kind: "organisation")
    login(company.email)
    get edit_account_profile_path
    assert_response :success
    patch account_profile_path, params: { add_section: "products", submission: { organisation_name: "New orchard", products: [ { name: "Juice", special: "Local", impact: "Less waste" } ] } }
    assert_response :success
    assert_select "textarea#submission_products_1_name"
    assert_equal "Orchard", company.reload.organisation_name
    patch account_profile_path, params: { submission: { organisation_name: "New orchard", target_ids: [ "12.3" ], sectors_past: [ ProfileOptions::SECTORS.first ] } }
    assert_redirected_to dashboard_path
    assert_equal [ "12.3" ], company.reload.target_ids
  end
  test "expired sessions require login and codes cannot be replayed" do
    owned = profile
    login(owned.email)
    code = ActionMailer::Base.deliveries.last.body.decoded[/code is (\d{6})/, 1]
    post verify_login_path, params: { code: code }
    assert_response :unprocessable_entity
    travel 31.days do
      get dashboard_path
      assert_redirected_to login_path
      patch account_profile_path, params: { submission: { name: "Expired" } }
      assert_redirected_to login_path
    end
    assert_equal "Alex", owned.reload.name
  end

  test "delivery failures do not report a sent code or grant access" do
    original_method = LoginMailer.delivery_method
    failing_delivery = Class.new do
      def initialize(*)
      end

      def deliver!(_mail)
        raise IOError, "Delivery unavailable"
      end
    end
    LoginMailer.delivery_method = failing_delivery
    post login_path, params: { email: "delivery@example.test" }
    assert_response :service_unavailable
    assert_select "p[role=alert]", text: /couldn't send/
    assert LoginCode.last.used_at
    get dashboard_path
    assert_redirected_to login_path
  ensure
    LoginMailer.delivery_method = original_method
  end

  test "login requests require CSRF tokens" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference "LoginCode.count" do
      post login_path, params: { email: "csrf@example.test" }
    end
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "image removal survives validation and repeaters without accepting other image IDs" do
    project = { "title" => "Local food", "role" => "Researcher", "problem" => "Waste", "context" => "Food", "approach" => "Reuse", "results" => "Less waste" }
    owned = profile(projects: [ project ])
    image = PortfolioImage.create!(submission: owned, upload_owner: "test", content_type: "image/png", data: "test image")
    owned.update!(projects: [ project.merge("image_id" => image.id) ])
    login(owned.email)
    patch account_profile_path, params: { submission: { name: "Updated", projects: [ project.merge("image_id" => 999999) ] } }
    assert_redirected_to dashboard_path
    assert_equal image.id, owned.reload.projects.first["image_id"]
    patch account_profile_path, params: { add_section: "skills", submission: { projects: [ project.merge("remove_image" => "1") ] } }
    assert_response :success
    assert_select "input[type=hidden][name='submission[projects][][remove_image]'][value='1']"
    patch account_profile_path, params: { submission: { projects: [ project.merge("remove_image" => "1") ] } }
    assert_redirected_to dashboard_path
    assert_nil owned.reload.projects.first["image_id"]
    assert_not PortfolioImage.exists?(image.id)
  end
  test "profile and quiz requests cannot target someone else's profile" do
    person = profile
    other = profile(email: "other@example.test")
    login(person.email)
    patch account_profile_path, params: { profile_id: other.id, submission: { name: "Not allowed" } }
    assert_response :not_found
    assert_equal "Alex", other.reload.name
    post quiz_path, params: { profile_id: other.id, question: 0, answer: "0" }
    assert_response :not_found
  end

  test "login claims only one legacy profile and never replaces it" do
    first = profile
    second = profile(kind: "organisation")
    login(first.email)
    assert first.reload.account_id
    assert_nil second.reload.account_id
    delete logout_path
    login(first.email)
    assert_equal first.id, Account.find_by!(email: first.email).submission.id
    assert_nil second.reload.account_id
  end

  test "owners can add companies but keep one personal profile" do
    owned = profile
    login(owned.email)
    get new_person_path
    assert_redirected_to edit_account_profile_path
    get new_organisation_path
    assert_response :success
    get dashboard_path
    assert_select "a[href='#{new_organisation_path}']", text: "Create a company profile"
    assert_select "a[href='#{new_challenge_path}']", text: "Start a project"
    assert_no_difference "Submission.count" do
      post people_path, params: { submission: { name: "Duplicate", email: owned.email } }
    end
    assert_redirected_to edit_account_profile_path
    assert_difference "Submission.count", 1 do
      post organisations_path, params: { submission: { name: "Alex", organisation_name: "New company", mission: "Help", purpose: "Community", offering: "Services", challenge_kind: "Goals", challenge: "Grow", consent: "1", email: "forged@example.test", account_id: 1234 } }
    end
    company = Submission.last
    assert_equal owned.reload.account_id, company.account_id
    assert_equal owned.email, company.email
    get dashboard_path
    assert_select "h1 a", text: "New company"
    assert_select "select[name=selected_profile_id] option", count: 2
    patch switch_profile_path, params: { selected_profile_id: owned.id }
    assert_redirected_to dashboard_path
    get dashboard_path
    assert_select "h1 a", text: owned.display_name
    assert_equal owned.id, owned.account.submission.id
    delete logout_path
    assert_no_difference "Submission.count" do
      post organisations_path, params: { submission: { name: "Duplicate", email: owned.email } }
    end
    assert_redirected_to login_path
  end

  test "an account without a profile creates its one profile using its verified email" do
    login("new@example.test")
    post people_path, params: { submission: { name: "New owner", email: "other@example.test", purpose: "Help", experience: "Work", consent: "1" } }
    assert_redirected_to dashboard_path
    owned = Account.find_by!(email: "new@example.test").submission
    assert_equal "new@example.test", owned.email
    assert_equal "New owner", owned.name
  end

  test "private previews and their images are visible only to the owner" do
    owned = profile(published: false)
    image = PortfolioImage.create!(submission: owned, upload_owner: "test", content_type: "image/png", data: "private image")
    get profile_path(owned.public_slug)
    assert_response :not_found
    login(owned.email)
    get profile_path(owned.public_slug)
    assert_response :success
    assert_select "p", text: /Only you can see this preview/
    assert_no_match owned.email, response.body
    get portfolio_image_path(image)
    assert_response :success
    delete logout_path
    login("stranger@example.test")
    get profile_path(owned.public_slug)
    assert_response :not_found
    get portfolio_image_path(image)
    assert_response :not_found
    get people_path
    assert_select ".directory-card", count: 0
  end

  test "personal profile ownership is unique in both validation and the database" do
    owned = profile
    login(owned.email)
    duplicate = profile(email: "duplicate@example.test")
    duplicate.account_id = owned.reload.account_id
    assert_not duplicate.valid?
    assert duplicate.errors[:account_id].any?
    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.update_columns(account_id: owned.account_id)
    end
  end

  test "account creation verifies the submitted email and claims the pending profile" do
    older = profile(email: "signup@example.test")
    post people_path, params: { submission: { name: "Alex", email: "signup@example.test", purpose: "Help communities", experience: "Local work", consent: "1" } }
    assert_redirected_to create_account_path
    post login_path, params: { signup: "1", email: "different@example.test" }
    assert_redirected_to verify_login_path
    assert_equal [ "different@example.test" ], ActionMailer::Base.deliveries.last.to
    pending = Submission.order(:id).last
    code = ActionMailer::Base.deliveries.last.body.decoded[/code is (\d{6})/, 1]
    post verify_login_path, params: { code: code }
    assert_redirected_to dashboard_path
    assert_equal "different@example.test", pending.reload.email
    assert_equal pending.id, Account.find_by!(email: "different@example.test").submission.id
    assert_nil older.reload.account_id
  end
  test "signup email corrections validate and preserve the form" do
    post people_path, params: { submission: { name: "Alex", email: "typo@example.test", purpose: "Help", experience: "Work", consent: "1" } }
    pending = Submission.last
    get create_account_path
    assert_select "input[name=email][readonly]", count: 0
    assert_no_difference "LoginCode.count" do
      post login_path, params: { signup: "1", email: "invalid" }
    end
    assert_response :unprocessable_entity
    assert_select "input[name=email][value=invalid]"
    assert_select "input[name=signup][value='1']"
    assert_equal "typo@example.test", pending.reload.email
    owned = profile(email: "existing@example.test", account: Account.create!(email: "existing@example.test"))
    assert_no_difference "LoginCode.count" do
      post login_path, params: { signup: "1", email: owned.email }
    end
    assert_response :unprocessable_entity
    assert_equal "typo@example.test", pending.reload.email
    assert_equal owned.id, owned.account.submission.id
  end
end
