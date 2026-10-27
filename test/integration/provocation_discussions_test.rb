require "test_helper"

class ProvocationDiscussionsTest < ActionDispatch::IntegrationTest
  setup do
    @author = Account.create!(email: "note-author@example.test")
    @reader = Account.create!(email: "note-reader@example.test")
    @author_profile = person(@author, "Author Identity")
    @reader_profile = person(@reader, "Reader Identity")
    @question = Provocation.create!(key: "discussion", question: "Should we share more?", goal_id: "12", position: 1)
    @answer = @author_profile.provocation_answers.create!(provocation: @question, choice: "yes", note: "A private thought")
  end

  test "public permalink hides notes and drafts; member sharing is explicit and withdrawal works" do
    get provocation_path(@question)
    assert_response :success
    assert_no_match "A private thought", response.body
    @question.update!(status: "retired")
    get provocation_path(@question)
    assert_response :success
    draft = Provocation.create!(key: "draft", question: "Draft?", goal_id: "1", position: 1, status: "draft")
    get provocation_path(draft)
    assert_response :not_found
    sign_in_account(@reader)
    get provocation_path(@question, results: 1)
    assert_select ".shared-note", count: 0
    assert_select "p", text: "Still gathering responses."
    @answer.update!(shared: true)
    get provocation_path(@question, results: 1)
    assert_select ".shared-note", text: /A private thought/
    assert_no_match "Author Identity", response.body
    assert_no_match @author.email, response.body
    assert_no_match @author_profile.public_slug, response.body
    @answer.update!(shared: false)
    get provocation_path(@question)
    assert_select ".shared-note", count: 0
  end

  test "owner can save edit and delete notes without exposing the profile section to others" do
    sign_in_account(@author)
    post profile_provocation_answers_path(@author_profile.public_slug), params: {
      provocation_id: @question.id, choice: "strong_no", note: "A revised thought", shared: "1", allow_introductions: "1", return_to_provocation: "1"
    }
    assert_redirected_to provocation_path(@question)
    assert_equal "A revised thought", @answer.reload.note
    assert @answer.shared?
    get profile_path(@author_profile.public_slug)
    assert_select "#your-answers-title", text: "Your answers"
    sign_in_account(@reader)
    get profile_path(@author_profile.public_slug)
    assert_select "#your-answers-title", count: 0
    delete profile_provocation_answer_path(@author_profile.public_slug, @answer)
    assert_response :not_found
    sign_in_account(@author)
    assert_difference "ProvocationAnswer.count", -1 do
      delete profile_provocation_answer_path(@author_profile.public_slug, @answer)
    end
  end

  test "temperature uses only opted in answers and preserves a split without numerical counts" do
    @answer.update!(shared: true, choice: "strong_no")
    4.times do |i|
      account = Account.create!(email: "temperature-#{i}@example.test")
      person(account, "Voter #{i}").provocation_answers.create!(provocation: @question, choice: "strong_yes", shared: true)
    end
    sign_in_account(@reader)
    get provocation_path(@question)
    assert_select ".response-temperature", count: 0
    get provocation_path(@question, results: 1)
    assert_select ".temperature-cell", count: 4
    assert_select ".temperature-3", text: "Strong YesHot"
    assert_select ".temperature-cell", text: /\d/, count: 0
  end

  test "introductions require two consents and recipient authentication and send once" do
    @answer.update!(shared: true, allow_introductions: true)
    sign_in_account(@reader)
    assert_no_difference "ProvocationIntroduction.count" do
      post provocation_introductions_path, params: { provocation_answer_id: @answer.id }
    end
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      post provocation_introductions_path, params: { provocation_answer_id: @answer.id, consent: "1" }
    end
    request = ProvocationIntroduction.sole
    email = ActionMailer::Base.deliveries.last
    assert_equal [ @author.email ], email.to
    assert_includes email.body.decoded, @reader.email
    assert_includes email.body.decoded, provocation_introduction_path(request)
    get provocation_introduction_path(request)
    assert_response :not_found
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      post provocation_introductions_path, params: { provocation_answer_id: @answer.id, consent: "1" }
    end
    sign_in_account(@author)
    get provocation_introduction_path(request)
    assert_response :success
    assert_equal "pending", request.reload.status
    patch provocation_introduction_path(request), params: { decision: "accept" }
    assert_equal "pending", request.reload.status
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      patch provocation_introduction_path(request), params: { decision: "accept", consent: "1" }
    end
    assert_equal "accepted", request.reload.status
    assert_equal [ @reader.email, @author.email ].sort, ActionMailer::Base.deliveries.last.to.sort
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      patch provocation_introduction_path(request), params: { decision: "accept", consent: "1" }
    end
  end

  test "declining prevents repeated requests and withdrawn notes cannot be accepted" do
    @answer.update!(shared: true, allow_introductions: true)
    request = ProvocationIntroduction.create!(requester: @reader, recipient: @author, provocation_answer: @answer)
    sign_in_account(@author)
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      patch provocation_introduction_path(request), params: { decision: "decline" }
    end
    assert_equal "declined", request.reload.status
    sign_in_account(@reader)
    assert_no_difference "ProvocationIntroduction.count" do
      post provocation_introductions_path, params: { provocation_answer_id: @answer.id, consent: "1" }
    end
    request.update!(status: "pending")
    @answer.update!(shared: false)
    sign_in_account(@author)
    patch provocation_introduction_path(request), params: { decision: "accept", consent: "1" }
    assert_equal "pending", request.reload.status
    @answer.update!(shared: true)
    request.update!(created_at: 31.days.ago)
    assert_not request.available?
  end

  test "request limit and unavailable authors are enforced" do
    @answer.update!(shared: true, allow_introductions: false)
    request = ProvocationIntroduction.new(requester: @reader, recipient: @author, provocation_answer: @answer)
    assert_not request.valid?
    @answer.update!(allow_introductions: true)
    5.times do |i|
      account = Account.create!(email: "recipient-#{i}@example.test")
      answer = person(account, "Recipient").provocation_answers.create!(provocation: @question, choice: "yes", note: "Shared", shared: true, allow_introductions: true)
      ProvocationIntroduction.create!(requester: @reader, recipient: account, provocation_answer: answer)
    end
    assert_not request.valid?
    assert_includes request.errors.full_messages.to_sentence, "five introductions"
  end

  test "email failures leave requests retryable without recording acceptance" do
    @answer.update!(shared: true, allow_introductions: true)
    sign_in_account(@reader)
    original_delivery_method = ProvocationIntroductionMailer.delivery_method
    failing_delivery = Class.new do
      def initialize(*)
      end

      def deliver!(*)
        raise IOError, "Mail server unavailable"
      end
    end
    ProvocationIntroductionMailer.add_delivery_method :provocation_failure, failing_delivery
    ProvocationIntroductionMailer.delivery_method = :provocation_failure
    assert_no_difference "ProvocationIntroduction.count" do
      post provocation_introductions_path, params: { provocation_answer_id: @answer.id, consent: "1" }
    end
    request = ProvocationIntroduction.create!(requester: @reader, recipient: @author, provocation_answer: @answer)
    sign_in_account(@author)
    patch provocation_introduction_path(request), params: { decision: "accept", consent: "1" }
    assert_equal "pending", request.reload.status
  ensure
    ProvocationIntroductionMailer.delivery_method = original_delivery_method
  end

  test "retired and draft questions leave the rotation and notes cannot bypass their access rules" do
    @question.update!(status: "retired")
    sign_in_account(@reader)
    get dashboard_path
    assert_select "legend", text: @question.question, count: 0
    assert_no_difference "ProvocationAnswer.count" do
      post profile_provocation_answers_path(@reader_profile.public_slug), params: { provocation_id: @question.id, choice: "yes" }
    end
    assert_response :not_found
    sign_in_account(@author)
    post profile_provocation_answers_path(@author_profile.public_slug), params: { provocation_id: @question.id, choice: "no", note: "x" * 2001 }
    assert_equal "A private thought", @answer.reload.note
    @answer.update!(note: '<script>alert("x")</script>', shared: true)
    get provocation_path(@question)
    assert_select ".shared-note script", count: 0
  end

  private

  def person(account, name)
    Submission.create!(account: account, kind: "person", profile_version: 2, name: name, email: account.email,
      purpose: "Useful work", experience: "Building things", consent: "1")
  end
end
