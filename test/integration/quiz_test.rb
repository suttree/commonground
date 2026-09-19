require "test_helper"

class QuizTest < ActionDispatch::IntegrationTest
  test "all goals and targets are available with original wording" do
    assert_equal ProfileOptions::TARGETS.keys.sort, SdgQuiz::LABELS.keys.sort
    get quiz_path
    assert_response :success
    assert_select "input[name='goals[]']", count: 17
    ProfileOptions::GOALS.each do |goal|
      post quiz_path, params: { step: "targets", goals: [ goal.fetch("id") ] }
      assert_response :success
      assert_select "input[name='targets[]']", count: goal.fetch("targets").size
      goal.fetch("targets").each do |target|
        assert_select ".quiz-target details p", text: target.fetch("text")
      end
    end
  end

  test "answers survive navigation and results show only selected priorities" do
    goals = %w[11 12 17]
    targets = %w[11.3 12.6 17.17]
    post quiz_path, params: { step: "results", goals: goals, targets: targets }
    assert_response :success
    assert_select ".quiz-answer", count: 3
    assert_select "h3", text: SdgQuiz::LABELS.fetch("12.6")
    post quiz_path, params: { step: "targets", goals: goals, targets: targets }
    assert_select "input[name='targets[]'][checked]", count: 3
    post quiz_path, params: { step: "topics", goals: goals, targets: targets }
    assert_select "input[name='goals[]'][checked]", count: 3
    post quiz_path, params: { step: "targets", goals: [ "11" ], targets: targets }
    assert_select "input[name='targets[]'][checked]", count: 1
    post quiz_path, params: { step: "results", goals: [ "11" ], targets: [ "11.3" ] }
    assert_response :success
    assert_select ".quiz-answer", count: 1
    get quiz_path
    assert_select "input[checked]", count: 0
  end

  test "invalid choices cannot bypass the limits or topic filtering" do
    [ [], %w[1 2 3 4], [ "unknown" ], "11" ].each do |goals|
      post quiz_path, params: { step: "targets", goals: goals }
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
    end
    [ [], %w[11.1 11.2 11.3 11.4], [ "12.6" ], [ "unknown" ], "11.3" ].each do |targets|
      post quiz_path, params: { step: "results", goals: [ "11" ], targets: targets }
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
      assert_select ".quiz-answer", count: 0
    end
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
