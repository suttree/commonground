require "test_helper"
require "rake"

class InvitationRemindersTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    load Rails.root.join("lib/tasks/emails.rake") unless Rake::Task.task_defined?("emails:invitation_reminders")
    Rake::Task.define_task(:environment)
    @owner = Submission.create!(kind: "person", profile_version: 2, name: "Owner", email: "owner@example.test",
      purpose: "Community", experience: "Gardening", consent: "1", published: true)
    @project = @owner.challenges.create!(title: "Community garden", status: "active",
      description: "Grow food", objectives: "Open a garden", location: "Bristol")
  end

  test "the daily task sends a due reminder only once" do
    invitation = invite("due")

    assert_emails 1 do
      run_reminders
    end
    assert invitation.reload.reminded_at
    assert_equal [ invitation.email ], ActionMailer::Base.deliveries.last.to
    assert_includes ActionMailer::Base.deliveries.last.body.decoded, invitation.token

    assert_no_emails do
      run_reminders
    end
  end

  test "the daily task skips invitations that are not eligible" do
    invitations = [
      invite("accepted", accepted_at: Time.current),
      invite("revoked", revoked_at: Time.current),
      invite("already-reminded", reminded_at: Time.current),
      invite("unsent", sent_at: nil),
      invite("expired", expires_at: 1.minute.ago),
      invite("later", expires_at: 2.days.from_now)
    ]
    private_project = @owner.challenges.create!(title: "Private garden", status: "draft")
    invitations << invite("private", challenge: private_project)

    assert_no_emails do
      run_reminders
    end
    invitations.reject { |invitation| invitation.email == "already-reminded@example.test" }.each do |invitation|
      assert_nil invitation.reload.reminded_at
    end
  end

  private

  def invite(name, **attributes)
    CollaboratorInvitation.create!({ challenge: @project, email: "#{name}@example.test",
      sent_at: 13.days.ago, expires_at: 12.hours.from_now }.merge(attributes))
  end

  def run_reminders
    task = Rake::Task["emails:invitation_reminders"]
    task.reenable
    task.invoke
  end
end
