class DashboardsController < ApplicationController
  before_action :require_account
  before_action :check_profile_id

  def show
    @profile = current_profile
  end
end
