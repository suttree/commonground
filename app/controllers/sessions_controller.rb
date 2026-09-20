class SessionsController < ApplicationController
  before_action { response.headers["Cache-Control"] = "no-store" }

  def new
  end

  def create_account
    @pending_submission = Submission.where(account_id: nil).find_by(id: session[:pending_submission_id])
    redirect_to new_person_path unless @pending_submission
  end

  def create
    if params[:signup] == "1"
      @pending_submission = Submission.where(account_id: nil).find_by(id: session[:pending_submission_id])
      return redirect_to new_person_path unless @pending_submission
    end
    email = params[:email].to_s.strip.downcase
    @email = email
    unless email.length <= 254 && email.match?(URI::MailTo::EMAIL_REGEXP)
      @error = "Enter a valid email address."
      return render(params[:signup] == "1" ? :create_account : :new, status: :unprocessable_entity)
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
      return render(params[:signup] == "1" ? :create_account : :new, status: :too_many_requests)
    end
    challenge, code = issued
    begin
      LoginMailer.code(email, code).deliver_now
    rescue StandardError => error
      challenge.update!(used_at: Time.current)
      Rails.logger.error("Login email delivery failed: #{error.class.name}")
      @error = "We couldn't send your code. Please try again later."
      return render(params[:signup] == "1" ? :create_account : :new, status: :service_unavailable)
    end
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
    reset_session
    session[:account_id] = account.id
    session[:authenticated_at] = Time.current.to_i
    redirect_to dashboard_path, status: :see_other
  end

  def destroy
    reset_session
    redirect_to root_path, status: :see_other
  end
end
