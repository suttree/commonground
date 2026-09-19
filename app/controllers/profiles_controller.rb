class ProfilesController < ApplicationController
  def show
    @profile = Submission.published.find_by!(public_slug: params[:slug])
    response.headers["Cache-Control"] = "no-store"
  end
end
