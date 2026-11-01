module Admin
  class BaseController < ApplicationController
    before_action :prevent_caching
    before_action :require_account
    before_action :require_admin_account

    private

    def require_admin_account
      head :forbidden unless current_account.admin?
    end

    def prevent_caching
      response.headers["Cache-Control"] = "no-store"
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
    end
  end
end
