class ChallengeCollaboratorsController < ApplicationController
  before_action :require_account

  def destroy
    challenge = current_account.challenges.find(params[:challenge_id])
    challenge.with_lock do
      ids = challenge.collaborator_ids.map(&:to_s)
      raise ActiveRecord::RecordNotFound unless ids.include?(params[:id])
      challenge.update!(collaborator_ids: ids - [ params[:id] ])
    end
    redirect_to challenge_path(challenge, anchor: "collaborators"), notice: "Collaborator removed from this project.", status: :see_other
  end
end
