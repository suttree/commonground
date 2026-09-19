class ContactRequestsController < ApplicationController
  before_action :find_recipient

  def new
    @contact_request = ContactRequest.new(intent: params[:intent].presence_in(ContactRequest::OPTIONS.keys) || "problem")
  end

  def create
    @contact_request = @recipient.contact_requests.build(params.require(:contact_request).permit(:intent, :name, :email, :message, :consent, :include_priorities, :website_confirmation))
    return head :unprocessable_entity if @contact_request.website_confirmation.present?
    @contact_request.target_ids = SdgQuiz.matches(session.fetch(:quiz_answers, {})).keys if @contact_request.include_priorities == "1"
    if @contact_request.save
      redirect_to profile_contact_thanks_path(@recipient.public_slug), status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def thanks
  end

  private

  def find_recipient
    @recipient = Submission.published.where(kind: "person").find_by!(public_slug: params[:slug])
    @priorities = SdgQuiz.matches(session.fetch(:quiz_answers, {})).keys
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end
end
