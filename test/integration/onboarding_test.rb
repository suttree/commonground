require "test_helper"

class OnboardingTest < ActionDispatch::IntegrationTest
  def join(email = "joining@example.test")
    post login_path, params: { individual_signup: "1", name: "Alex", email: email }
    assert_redirected_to verify_login_path
    code = ActionMailer::Base.deliveries.last.body.decoded[/^(\d{6})$/, 1]
    post verify_login_path, params: { code: code }
  end

  def complete_quiz
    get quiz_path
    8.times { |index| post quiz_path, params: { question: index, answer: "1" } }
  end

  test "verified signup confirms priorities then creates a short profile and finds companies" do
    get new_person_path
    assert_select "input[name=name]"
    assert_select "input[name=email]"
    assert_select "textarea", count: 0
    assert_no_difference "Submission.count" do
      join
      assert_redirected_to quiz_path
      complete_quiz
    end
    account = Account.find_by!(email: "joining@example.test")
    assert_equal 8, account.onboarding.fetch("quiz_answers").size
    get quiz_path
    assert_select "input[type=submit][value='Continue to your profile']"
    assert_select ".next-step-option", count: 3
    post confirm_quiz_path, params: { target_ids: [ "11.2", "12.3" ] }
    assert_redirected_to onboarding_profile_path
    get onboarding_profile_path
    assert_select "input[name='submission[location]']"
    assert_select "input[name='submission[name]'][value=Alex]"
    assert_difference "Submission.count", 1 do
      post onboarding_profile_path, params: { submission: { name: "Alex", purpose: "Help neighbours", experience: "Designer", skills_summary: "Research", location: "Bristol", consent: "1", email: "forged@example.test", kind: "organisation", account_id: 999 } }
    end
    assert_redirected_to companies_path(priorities: "1")
    profile = account.submissions.sole
    assert_equal "joining@example.test", profile.email
    assert_equal "person", profile.kind
    assert_equal [ "11.2", "12.3" ], profile.target_ids
    assert_equal "Research", profile.skills_summary
    assert_empty account.reload.onboarding
    get people_path(skill: "Research")
    assert_select ".directory-card h2", text: "Alex"
    get profile_path(profile.public_slug)
    assert_no_match "quiz_answers", response.body
  end

  test "signup can skip quiz resume after login and validates the short form" do
    join
    post skip_onboarding_quiz_path
    assert_redirected_to onboarding_profile_path
    post onboarding_profile_path, params: { submission: { name: "Alex" } }
    assert_response :unprocessable_entity
    assert_equal 0, Submission.where(email: "joining@example.test").count
    delete logout_path
    post login_path, params: { email: "joining@example.test" }
    code = ActionMailer::Base.deliveries.last.body.decoded[/^(\d{6})$/, 1]
    post verify_login_path, params: { code: code }
    get dashboard_path
    assert_select "a", text: "Continue setting up your profile"
    get new_person_path
    assert_redirected_to onboarding_profile_path
  end

  test "quiz choices are explicit validated and do not overwrite another profile" do
    join
    post confirm_quiz_path, params: { target_ids: [ "11.2" ] }
    assert_redirected_to quiz_path
    complete_quiz
    [ [ "unknown" ], %w[1.1 1.2 1.3 1.4], "11.2" ].each do |invalid|
      post confirm_quiz_path, params: { target_ids: invalid }
      assert_response :unprocessable_entity
    end
    assert_nil Account.find_by!(email: "joining@example.test").onboarding["target_ids"]
    post confirm_quiz_path, params: { target_ids: [ "" ] }
    assert_redirected_to onboarding_profile_path
  end

  test "company discovery uses all confirmed goals and filters can be cleared" do
    company = Submission.create!(kind: "organisation", profile_version: 2, name: "Owner", email: "company@example.test", organisation_name: "Orchard", mission: "Food", purpose: "Community", offering: "Fruit", challenge_kind: "Goals", challenge: "Grow", consent: "1", target_ids: [ "12.3" ])
    join
    complete_quiz
    post confirm_quiz_path, params: { target_ids: [ "11.2", "12.3" ] }
    get companies_path(priorities: "1")
    assert_select ".directory-card h2", text: company.display_name
    assert_select "a[href='#{companies_path}']", text: "Show all"
    post confirm_quiz_path, params: { target_ids: [ "11.2" ] }
    get companies_path(priorities: "1")
    assert_select ".directory-card", count: 0
    get companies_path
    assert_select ".directory-card", count: 1
  end
end
