class SubmissionsController < ApplicationController
  rate_limit to: 10, within: 10.minutes, only: :create,
    with: -> { render plain: "We've received several submissions from this connection. Please try again in ten minutes.", status: :too_many_requests }

  def new
    @submission = Submission.new(kind: submission_kind)
  end

  def create
    @submission = Submission.new(submission_params.merge(kind: submission_kind))
    if @submission.website_confirmation.present?
      redirect_to thanks_path, status: :see_other
    elsif @submission.save
      redirect_to thanks_path, status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def submission_kind
    request.path.start_with?("/organisations") ? "organisation" : "person"
  end

  def submission_params
    params.require(:submission).permit(:name, :email, :organisation_name, :website,
      :challenge, :purpose, :experience, :working_style, :engagement,
      :availability, :location, :pay_expectations, :consent, :website_confirmation)
  end
end
