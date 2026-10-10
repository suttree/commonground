class PagesController < ApplicationController
  def home
    @recent_challenges = Challenge.discoverable.includes(:submission).recent.limit(6)
  end

  def althomepage
    home
  end
  def about; end
  def privacy; end
  def thanks; end
end
