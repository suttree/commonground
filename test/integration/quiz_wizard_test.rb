require "test_helper"

class QuizWizardTest < ActionDispatch::IntegrationTest
  test "wizard completes, explains suggestions and retains edits" do
    get quiz_path
    assert_select "h1", text: "What matters to you?"
    assert_select "a[href='#{quiz_path(question: 0)}']", text: "Start the questions"
    get quiz_path(question: 0)
    assert_select "input[type=radio]", count: 5
    assert_select "h1", text: SdgQuiz::QUESTIONS.first.fetch("question")
    8.times do |index|
      post quiz_path, params: { question: index, answer: "1" }
      assert_response :see_other
      follow_redirect!
      assert_response :success
    end
    assert_select ".quiz-answer", count: 3
    assert_select ".next-step-option input[type=radio][name=intent][required]", count: 3
    assert_select ".next-step-option input[checked]", count: 0
    assert_select ".quiz-reasons li", minimum: 3
    get quiz_path(question: 3)
    assert_select "input[value='1'][checked]"
    post quiz_path, params: { question: 3, answer: "2" }
    follow_redirect!
    get quiz_path(question: 3)
    assert_select "input[value='2'][checked]"
    get quiz_path
    assert_select ".quiz-answer", count: 3
    post quiz_path, params: { restart: "1" }
    follow_redirect!
    assert_select "h1", text: "What matters to you?"
    get quiz_path(question: 0)
    assert_select "input[checked]", count: 0
  end

  test "skips do not create false matches and forged steps do not bypass wizard" do
    post quiz_path, params: { question: 7, answer: "1" }
    follow_redirect!
    assert_select "h1", text: "What matters to you?"
    post quiz_path, params: { question: 0, answer: "invalid" }
    assert_response :unprocessable_entity
    assert_select "[role=alert]"
    8.times do |index|
      post quiz_path, params: { question: index, answer: "skip" }
      follow_redirect!
    end
    assert_select ".quiz-answer", count: 0
    assert_select "h1", text: "Still exploring? That's fine."
  end

  test "question mapping covers every goal and uses only known targets" do
    targets = SdgQuiz::QUESTIONS.flat_map { |question| question.fetch("options").flat_map { |option| option.fetch("targets") } }
    assert_empty targets - ProfileOptions::TARGETS.keys
    assert_equal ProfileOptions::GOALS.pluck("id").sort, targets.map { |id| id.split(".").first }.uniq.sort
    assert_empty SdgQuiz.matches({})
    answers = (0...8).to_h { |index| [ index.to_s, "skip" ] }
    answers["1"] = "1"
    assert_equal %w[12.6 12.5], SdgQuiz.matches(answers).keys
    answers["6"] = "1"
    assert_equal "12.6", SdgQuiz.matches(answers).keys.first
  end
end
