class ProvocationAnswersController < ApplicationController
  before_action :require_account

  def create
    profile = current_account.submissions.find_by!(public_slug: params[:slug], kind: "person")
    provocation = Provocation.find(params[:provocation_id])
    answer = profile.provocation_answers.find_or_initialize_by(provocation: provocation)
    answer.choice = params[:choice]
    if answer.save
      redirect_to profile_path(profile.public_slug, anchor: "provocations"), notice: "Answer saved.", status: :see_other
    else
      redirect_to profile_path(profile.public_slug, anchor: "provocations"), alert: "Choose one of the four answers.", status: :see_other
    end
  end
end
