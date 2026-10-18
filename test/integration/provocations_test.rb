require "test_helper"

class ProvocationsTest < ActionDispatch::IntegrationTest
  setup do
    @account = Account.create!(email: "provocations@example.test")
    @profile = Submission.create!(account: @account, kind: "person", profile_version: 2,
      name: "Alex", email: @account.email, purpose: "Useful work", experience: "Building things", consent: "1")
    @first = Provocation.create!(key: "test-first", question: "Should products be repairable?", goal_id: "12", position: -2)
    @second = Provocation.create!(key: "test-second", question: "Should cities prioritise buses?", goal_id: "11", position: -1)
  end

  test "owner answers, advances, revisits and changes an answer without duplicates" do
    sign_in_account(@account)
    get profile_path(@profile.public_slug)
    assert_select "#provocations legend", text: @first.question
    assert_select "#provocations a[href='#{sdg_goal_path('12')}']"
    assert_difference "ProvocationAnswer.count", 1 do
      post profile_provocation_answers_path(@profile.public_slug), params: { provocation_id: @first.id, choice: "strong_yes" }
    end
    follow_redirect!
    assert_select "#provocations > .provocation-form legend", text: @second.question
    assert_select ".provocation-history", text: /Strong Yes/
    assert_equal "12", @profile.provocation_answers.sole.provocation.goal_id
    assert_no_difference "ProvocationAnswer.count" do
      post profile_provocation_answers_path(@profile.public_slug), params: { provocation_id: @first.id, choice: "no" }
    end
    assert_equal "no", @profile.provocation_answers.sole.choice
  end

  test "anonymous visitors and other accounts cannot read or write answers" do
    @profile.provocation_answers.create!(provocation: @first, choice: "yes")
    get profile_path(@profile.public_slug)
    assert_select "#provocations", count: 0
    post profile_provocation_answers_path(@profile.public_slug), params: { provocation_id: @second.id, choice: "yes" }
    assert_redirected_to login_path
    sign_in_account(Account.create!(email: "other@example.test"))
    get profile_path(@profile.public_slug)
    assert_select "#provocations", count: 0
    assert_no_difference "ProvocationAnswer.count" do
      post profile_provocation_answers_path(@profile.public_slug), params: { provocation_id: @second.id, choice: "yes" }
    end
    assert_response :not_found
  end

  test "skip advances without an answer and invalid choices do not save" do
    sign_in_account(@account)
    assert_no_difference "ProvocationAnswer.count" do
      get profile_path(@profile.public_slug, after_provocation: @first.id)
    end
    assert_select "#provocations legend", text: @second.question
    assert_no_difference "ProvocationAnswer.count" do
      post profile_provocation_answers_path(@profile.public_slug), params: { provocation_id: @first.id, choice: "maybe" }
    end
    follow_redirect!
    assert_select "[role=alert]", text: "Choose one of the four answers."
    post profile_provocation_answers_path(@profile.public_slug), params: { provocation_id: 0, choice: "yes" }
    assert_response :not_found
  end

  test "all answered state retains editable history and original question" do
    sign_in_account(@account)
    Provocation.find_each { |question| @profile.provocation_answers.create!(provocation: question, choice: "yes") }
    get profile_path(@profile.public_slug)
    assert_select "#provocations", text: /You've answered all the questions/
    assert_select "#provocations > .provocation-form", count: 0
    assert_not @first.update(question: "A different question?")
    assert_not @first.update(goal_id: "1")
    assert_equal "Should products be repairable?", @first.reload.question
    @profile.destroy!
    assert_empty ProvocationAnswer.where(submission_id: @profile.id)
  end
end
