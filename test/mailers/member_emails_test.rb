require "test_helper"

class MemberEmailsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @member = Submission.create!(kind: "person", profile_version: 2, name: "Nika", email: "nika@example.test",
      purpose: "Useful work", experience: "Projects", consent: "1", published: true)
  end

  test "a contact request emails the member with a reply-to for the sender" do
    assert_emails 1 do
      post profile_contact_path(@member.public_slug), params: { contact_request: { intent: "coffee", name: "Visitor",
        email: "visitor@example.test", message: "Shall we talk?", consent: "1" } }
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "nika@example.test" ], mail.to
    assert_equal [ "visitor@example.test" ], mail.reply_to
    assert_equal "Someone’s commonbounding you!", mail.subject
    assert_match "Shall we talk?", mail.body.to_s
  end

  test "login, welcome and reminder emails use the new copy" do
    assert_equal "Let’s Commonbound to faster solutions.", LoginMailer.code("a@example.test", "123456").subject
    assert_match "123456", LoginMailer.code("a@example.test", "123456").body.to_s
    assert_equal "Welcome to Commonbound!", MemberMailer.welcome("a@example.test").subject
  end
end
