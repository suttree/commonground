class SessionsController < ApplicationController
  before_action { response.headers["Cache-Control"] = "no-store" }

  def new
  end

  def create_account
    @pending_submission = Submission.where(account_id: nil).find_by(id: session[:pending_submission_id])
    redirect_to new_person_path unless @pending_submission
  end

  def create
    signup_view = params[:individual_signup] == "1" ? "onboarding/new" : (params[:signup] == "1" ? :create_account : :new)
    if params[:individual_signup] == "1" && (params[:name].to_s.strip.blank? || params[:name].to_s.length > 200)
      @error = "Enter your name, up to 200 characters."
      return render signup_view, status: :unprocessable_entity
    end
    if params[:signup] == "1"
      @pending_submission = Submission.where(account_id: nil).find_by(id: session[:pending_submission_id])
      return redirect_to new_person_path unless @pending_submission
    end
    email = params[:email].to_s.strip.downcase
    @email = email
    unless email.length <= 254 && email.match?(URI::MailTo::EMAIL_REGEXP)
      @error = "Enter a valid email address."
      return render(signup_view, status: :unprocessable_entity)
    end
    if @pending_submission
      if Account.joins(:submission).exists?(email: email)
        @error = "This email already has a profile. Log in to edit it, or use a different email."
        return render :create_account, status: :unprocessable_entity
      end
      @pending_submission.with_lock do
        raise ActiveRecord::RecordNotFound if @pending_submission.account_id.present?
        @pending_submission.update!(email: email)
      end
    end
    issued = LoginCode.issue(email, request.remote_ip)
    unless issued
      @error = "Too many codes requested. Please try again in ten minutes."
      return render(signup_view, status: :too_many_requests)
    end
    challenge, code = issued
    begin
      LoginMailer.code(email, code).deliver_now
    rescue StandardError => error
      challenge.update!(used_at: Time.current)
      Rails.logger.error("Login email delivery failed: #{error.class.name}")
      @error = "We couldn't send your code. Please try again later."
      return render(signup_view, status: :service_unavailable)
    end
    session[:individual_signup_name] = params[:individual_signup] == "1" ? params[:name].to_s.strip : nil
    session[:login_code_id] = challenge.id
    redirect_to verify_login_path, status: :see_other
  end

  def verify
    redirect_to login_path unless session[:login_code_id]
  end

  def authenticate
    challenge = LoginCode.find_by(id: session[:login_code_id])
    unless challenge&.consume(params[:code])
      @error = "That code is incorrect or has expired. Codes last ten minutes and allow five attempts."
      return render :verify, status: :unprocessable_entity
    end
    account = Account.find_or_create_by!(email: challenge.email)
    account.with_lock do
      unless account.submission
        candidates = Submission.where(account_id: nil, email: account.email)
        profile = candidates.find_by(id: session[:pending_submission_id]) || candidates.order(:id).first
        profile&.update!(account: account)
      end
    end
    signup_name = session[:individual_signup_name]
    joining = signup_name.present? && !account.submissions.exists?(kind: "person")
    if joining
      draft = account.onboarding.merge("name" => signup_name)
      if session[:confirmed_quiz_targets].is_a?(Array)
        draft.merge!("target_ids" => session[:confirmed_quiz_targets], "quiz_answers" => session.fetch(:quiz_answers, {}),
          "confirmed" => Time.current.iso8601, "quiz_done" => true)
      end
      account.update!(onboarding: draft)
    end
    invitation_token = session[:collaborator_invitation_token]
    reset_session
    session[:collaborator_invitation_token] = invitation_token if invitation_token
    session[:account_id] = account.id
    session[:authenticated_at] = Time.current.to_i
    session[:onboarding_person] = true if joining
    destination = if joining
      account.onboarding["quiz_done"] ? onboarding_profile_path : quiz_path
    elsif invitation_token.present?
      invitation_path(token: invitation_token)
    else
      dashboard_path
    end
    redirect_to destination, status: :see_other
  end

  def destroy
    reset_session
    redirect_to root_path, status: :see_other
  end
end
