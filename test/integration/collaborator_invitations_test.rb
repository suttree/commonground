require "test_helper"

class CollaboratorInvitationsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = make_profile("owner@example.test")
    @recipient = make_profile("recipient@example.test")
    @challenge = @owner.challenges.create!(title: "Community garden", status: "active", description: "Grow food", objectives: "Open a garden", location: "Bristol")
  end

  def make_profile(email)
    Submission.create!(kind: "person", profile_version: 2, name: "Member", email: email, purpose: "Community", experience: "Gardening", consent: "1")
  end

  def login(email)
    post login_path, params: { email: email }
    code = ActionMailer::Base.deliveries.last.body.decoded[/code is (\d{6})/, 1]
    post verify_login_path, params: { code: code }
  end

  def invite(email = @recipient.email)
    post challenge_collaborator_invitations_path(@challenge), params: { collaborator_invitation: { email: email } }
    @challenge.collaborator_invitations.last
  end

  test "owner sends private invitation and recipient signs in then explicitly accepts" do
    login(@owner.email)
    invitation = nil
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      invitation = invite(" RECIPIENT@example.test ")
    end
    assert_redirected_to challenge_collaborator_invitations_path(@challenge)
    assert invitation.sent_at
    assert_equal @recipient.email, invitation.email
    assert_match "Community garden", ActionMailer::Base.deliveries.last.body.decoded
    token = invitation.token
    delete logout_path
    get challenge_path(@challenge)
    assert_no_match @recipient.email, response.body
    get invitation_path(token: token)
    assert_select "a", text: "Sign in to continue"
    assert_no_match @recipient.email, response.body
    assert_equal "same-origin", response.headers["Referrer-Policy"]
    assert_select "script[src*=withcabin]", count: 0
    login(@recipient.email)
    assert_redirected_to invitation_path(token: token)
    assert_empty @challenge.reload.collaborator_ids
    get invitation_path(token: token)
    assert_select "button", text: "Accept invitation"
    patch invitation_path(token: token)
    assert_redirected_to challenge_path(@challenge)
    assert_equal [ @recipient.id ], @challenge.reload.collaborator_ids
    assert invitation.reload.accepted_at
    patch invitation_path(token: token)
    assert_equal [ @recipient.id ], @challenge.reload.collaborator_ids
    get edit_challenge_path(@challenge)
    assert_response :not_found
  end

  test "new emails use a short random token and the configured public domain" do
    login(@owner.email)
    invitation = invite
    assert_match(/\A[A-Za-z0-9_-]{32}\z/, invitation.token)
    assert_equal invitation.token, invitation.reload.token
    assert_equal invitation, CollaboratorInvitation.find_by_token(invitation.token)
    assert_nil CollaboratorInvitation.find_by_token("x" * 32)
    mail = CollaboratorInvitationMailer.with({}).invite(invitation)
    original_options = CollaboratorInvitationMailer.default_url_options
    begin
      CollaboratorInvitationMailer.default_url_options = { host: "commonbound.work", protocol: "https" }
      assert_includes mail.body.decoded, "https://commonbound.work/invitation?token=#{invitation.token}"
    ensure
      CollaboratorInvitationMailer.default_url_options = original_options
    end
    travel 15.days do
      assert_nil CollaboratorInvitation.find_by_token(invitation.token)
    end
  end

  test "previously emailed signed links still allow acceptance" do
    login(@owner.email)
    invitation = invite
    invitation.update_column(:short_token, nil)
    old_token = invitation.token
    assert_operator old_token.length, :>, 32
    delete logout_path
    get invitation_path(token: old_token)
    assert_response :success
    login(@recipient.email)
    patch invitation_path(token: old_token)
    assert invitation.reload.accepted_at
  end

  test "new recipient returns after profile creation" do
    login(@owner.email)
    invitation = invite("new@example.test")
    token = invitation.token
    delete logout_path
    get invitation_path(token: token)
    login("new@example.test")
    get invitation_path(token: token)
    assert_select "a", text: "Create your profile"
    post people_path, params: { submission: { name: "New member", purpose: "Grow food", experience: "Gardening", consent: "1" } }
    assert_redirected_to invitation_path(token: token)
    patch invitation_path(token: token)
    assert invitation.reload.accepted_at
  end

  test "wrong accounts private profiles and cancelled expired or tampered links cannot accept" do
    login(@owner.email)
    invitation = invite
    token = invitation.token
    patch invitation_path(token: token)
    assert_empty @challenge.reload.collaborator_ids
    delete logout_path
    login(@recipient.email)
    @recipient.update!(published: false)
    patch invitation_path(token: token)
    assert_nil invitation.reload.accepted_at
    @recipient.update!(published: true)
    invitation.update!(revoked_at: Time.current)
    patch invitation_path(token: token)
    assert_nil invitation.reload.accepted_at
    invitation.update!(revoked_at: nil, expires_at: 1.second.ago)
    patch invitation_path(token: token)
    assert_nil invitation.reload.accepted_at
    get invitation_path(token: "tampered")
    assert_response :not_found
    travel 15.days do
      get invitation_path(token: token)
      assert_response :not_found
    end
  end

  test "only owner manages invitations and cancellation permits fresh invitation" do
    login(@owner.email)
    invitation = invite
    assert_no_difference "CollaboratorInvitation.count" do
      invite
    end
    assert_response :unprocessable_entity
    delete challenge_collaborator_invitation_path(@challenge, invitation)
    assert invitation.reload.revoked_at
    replacement = invite
    assert_not_equal invitation.id, replacement.id
    delete logout_path
    login(@recipient.email)
    get challenge_collaborator_invitations_path(@challenge)
    assert_response :not_found
    post challenge_collaborator_invitations_path(@challenge), params: { collaborator_invitation: { email: "other@example.test" } }
    assert_response :not_found
    delete challenge_collaborator_invitation_path(@challenge, replacement)
    assert_response :not_found
    assert_nil replacement.reload.revoked_at
  end

  test "draft invitations and bulk sends are rejected" do
    login(@owner.email)
    @challenge.update!(status: "draft")
    assert_no_difference "CollaboratorInvitation.count" do
      invite
    end
    assert_response :unprocessable_entity
    @challenge.update!(status: "active")
    20.times { |i| @challenge.collaborator_invitations.create!(email: "member#{i}@example.test", expires_at: 14.days.from_now) }
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      invite
    end
    assert_response :unprocessable_entity
  end

  class FailedDelivery
    def self.delivering_email(message)
      raise IOError, "Test delivery failure"
    end
  end

  test "failed delivery invalidates the link and permits another attempt" do
    login(@owner.email)
    ActionMailer::Base.register_interceptor(FailedDelivery)
    invitation = invite
    assert_nil invitation.sent_at
    assert invitation.revoked_at
    follow_redirect!
    assert_select "[role=alert]", text: /couldn't send/
    ActionMailer::Base.unregister_interceptor(FailedDelivery)
    replacement = invite
    assert replacement.sent_at
  ensure
    ActionMailer::Base.unregister_interceptor(FailedDelivery)
  end

  test "unpublishing prevents an outstanding invitation being accepted" do
    login(@owner.email)
    invitation = invite
    token = invitation.token
    delete logout_path
    login(@recipient.email)
    @owner.update!(published: false)
    patch invitation_path(token: token)
    assert_nil invitation.reload.accepted_at
    assert_empty @challenge.reload.collaborator_ids
  end

  test "inline email forms send invitations and return to the project or edit page" do
    login(@owner.email)
    get challenge_path(@challenge)
    assert_select "#collaborators form[action='#{challenge_collaborator_invitations_path(@challenge)}']" do
      assert_select "input[name=return_to][value=project]"
      assert_select "input[type=email][required]"
    end
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      post challenge_collaborator_invitations_path(@challenge), params: { return_to: "project", collaborator_invitation: { email: "new-member@example.test" } }
    end
    assert_redirected_to challenge_path(@challenge, anchor: "collaborators")
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "new-member@example.test" ], mail.to
    assert_includes mail.body.decoded, "You do not need an account yet."
    assert_includes mail.body.decoded, @challenge.collaborator_invitations.last.token
    post challenge_collaborator_invitations_path(@challenge), params: { return_to: "edit", collaborator_invitation: { email: "another@example.test" } }
    assert_redirected_to edit_challenge_path(@challenge, anchor: "email-invitations")
    post challenge_collaborator_invitations_path(@challenge), params: { return_to: "https://untrusted.example", collaborator_invitation: { email: "third@example.test" } }
    assert_redirected_to challenge_collaborator_invitations_path(@challenge)
  end

  test "invalid inline invitations preserve the email and do not send a message" do
    login(@owner.email)
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      post challenge_collaborator_invitations_path(@challenge), params: { return_to: "edit", collaborator_invitation: { email: "invalid-address" } }
    end
    assert_response :unprocessable_entity
    assert_select ".error-summary[role=alert]"
    assert_select "input[type=email][value='invalid-address']"
    assert_select "input[name=return_to][value=edit]"
  end

  test "an invited newcomer completes current signup and is added after accepting" do
    login(@owner.email)
    invitation = invite("newcomer@example.test")
    token = invitation.token
    delete logout_path
    get invitation_path(token: token)
    assert_select "a[href='#{join_path}']", text: "Create an account"
    get join_path
    assert_select ".join-steps", text: /Accept your invitation/
    post login_path, params: { individual_signup: "1", name: "New collaborator", email: "newcomer@example.test" }
    code = ActionMailer::Base.deliveries.last.body.decoded[/code is (\d{6})/, 1]
    post verify_login_path, params: { code: code }
    assert_redirected_to quiz_path
    post skip_onboarding_quiz_path
    assert_redirected_to onboarding_profile_path
    get onboarding_profile_path
    assert_select "input[type=submit][value='Save profile & return to invitation']"
    post onboarding_profile_path, params: { submission: { name: "New collaborator", purpose: "Food for everyone", experience: "Gardening", consent: "1" } }
    assert_redirected_to invitation_path(token: token)
    assert_empty @challenge.reload.collaborator_ids
    follow_redirect!
    assert_select "[role=status]", text: "Your profile is ready. Accept the invitation below to join the project."
    assert_select "button", text: "Accept invitation"
    patch invitation_path(token: token), params: { profile_id: Account.find_by!(email: "newcomer@example.test").submission.id }
    assert_redirected_to challenge_path(@challenge)
    assert invitation.reload.accepted_at
    follow_redirect!
    assert_select "#collaborators a", text: "New collaborator"
    assert_select "#collaborators form", count: 0
  end

  test "removed collaborators can be reinvited but their original link cannot rejoin" do
    login(@owner.email)
    invitation = invite
    delete logout_path
    login(@recipient.email)
    patch invitation_path(token: invitation.token)
    assert invitation.reload.accepted_at
    delete logout_path
    login(@owner.email)
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      invite
    end
    assert_response :unprocessable_entity
    delete challenge_collaborator_path(@challenge, @recipient.id)
    assert_empty @challenge.reload.collaborator_ids
    replacement = invite
    assert_response :see_other
    assert_not_equal invitation.id, replacement.id
    delete logout_path
    login(@recipient.email)
    patch invitation_path(token: invitation.token)
    assert_empty @challenge.reload.collaborator_ids
    patch invitation_path(token: replacement.token)
    assert_equal [ @recipient.id ], @challenge.reload.collaborator_ids
  end

  test "acceptance works with CSRF protection while foreign origins and missing tokens are rejected" do
    login(@owner.email)
    invitation = invite
    delete logout_path
    login(@recipient.email)
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    path = invitation_path(token: invitation.token)
    get path
    assert_equal "same-origin", response.headers["Referrer-Policy"]
    token = css_select("form[action='#{path}'] input[name=authenticity_token]").sole["value"]
    patch path, params: { authenticity_token: token, profile_id: @recipient.id }, headers: { "Origin" => "https://untrusted.example" }
    assert_response :unprocessable_entity
    assert_empty @challenge.reload.collaborator_ids
    patch path, params: { profile_id: @recipient.id }, headers: { "Origin" => "http://www.example.com" }
    assert_response :unprocessable_entity
    assert_empty @challenge.reload.collaborator_ids
    patch path, params: { authenticity_token: token, profile_id: @recipient.id }, headers: { "Origin" => "http://www.example.com" }
    assert_redirected_to challenge_path(@challenge)
    assert_equal [ @recipient.id ], @challenge.reload.collaborator_ids
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
