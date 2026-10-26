require "test_helper"

class QuizTest < ActionDispatch::IntegrationTest
  test "retired explorer redirects to the short quiz" do
    get explore_quiz_path
    assert_redirected_to quiz_path
    assert_response :moved_permanently
    post explore_quiz_path, params: { step: "results", goals: [ "11" ], targets: [ "11.3" ] }
    assert_redirected_to quiz_path
    assert_response :see_other
    assert_equal ProfileOptions::TARGETS.keys.sort, SdgQuiz::LABELS.keys.sort
  end

  test "logged-out results lead to sign-up and keep the suggested priorities" do
    SdgQuiz::QUESTIONS.size.times { |index| post quiz_path, params: { question: index, answer: "1" } }
    get quiz_path(question: SdgQuiz::QUESTIONS.size)
    assert_select "form.quiz-signup input[type=submit][value=?]", "Create your account"
    assert_select ".priority-edit", count: 0
    targets = css_select("form.quiz-signup input[name='target_ids[]']").map { |input| input["value"] }.compact_blank
    assert_not_empty targets
    post confirm_quiz_path, params: { target_ids: [ "" ] + targets, signup: "1" }
    assert_redirected_to new_person_path
    assert_equal targets, session[:confirmed_quiz_targets]
  end

  test "example answers only appear on the intended published profile" do
    entry = Submission.create!(kind: "person", profile_version: 2, name: "Nika", email: "nika@example.test",
      purpose: "Useful work", experience: "Projects", consent: "1", published: true,
      public_slug: SdgQuiz::EXAMPLES.keys.first)
    get profile_path(entry.public_slug)
    assert_select "#quiz-answers .quiz-answer", count: 3
    assert_select "#quiz-answers", text: /Nika hasn't completed the quiz/
    entry.update!(public_slug: "another-person")
    get profile_path(entry.public_slug)
    assert_select "#quiz-answers", count: 0
  end
end
