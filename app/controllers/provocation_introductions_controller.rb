class ProvocationIntroductionsController < ApplicationController
  before_action :require_account
  before_action :find_request, only: [ :show, :update ]

  def create
    answer = ProvocationAnswer.shared.with_notes.find(params[:provocation_answer_id])
    unless params[:consent] == "1"
      return redirect_to provocation_path(answer.provocation), alert: "Agree to share your details before requesting an introduction."
    end
    current_account.with_lock do
      recipient = answer.submission.account
      if recipient && !ProvocationIntroduction.exists?(requester: current_account, recipient: recipient)
        request = ProvocationIntroduction.new(requester: current_account, recipient: recipient, provocation_answer: answer)
        if request.save
          ProvocationIntroductionMailer.requested(request).deliver_now
        else
          return redirect_to provocation_path(answer.provocation), alert: request.errors.full_messages.to_sentence
        end
      end
    end
    redirect_to provocation_path(answer.provocation), notice: "Your request is recorded. If an introduction is available, the author will receive it. You cannot send another request to the same author.", status: :see_other
  rescue Net::SMTPError, IOError, Timeout::Error, SocketError => error
    Rails.logger.error("Introduction email failed: #{error.class.name}")
    redirect_back fallback_location: dashboard_path, alert: "We could not send the introduction email. Please try again."
  end

  def show
  end

  def update
    @request.with_lock do
      unless @request.available?
        return redirect_to provocation_introduction_path(@request), alert: "This request is no longer available."
      end
      if params[:decision] == "accept" && params[:consent] == "1"
        @request.update!(status: "accepted")
        ProvocationIntroductionMailer.accepted(@request).deliver_now
      elsif params[:decision] == "decline"
        @request.update!(status: "declined")
      else
        return redirect_to provocation_introduction_path(@request), alert: "Choose a response and confirm sharing before accepting."
      end
    end
    redirect_to provocation_introduction_path(@request), notice: "Your response has been saved.", status: :see_other
  rescue Net::SMTPError, IOError, Timeout::Error, SocketError => error
    Rails.logger.error("Introduction email failed: #{error.class.name}")
    redirect_back fallback_location: dashboard_path, alert: "We could not send the introduction email. Please try again."
  end

  private

  def find_request
    @request = ProvocationIntroduction.where(recipient: current_account).find(params[:id])
  end
end
