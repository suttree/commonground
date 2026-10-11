module Admin
  class BaseController < ApplicationController
    before_action :prevent_caching
    before_action :authenticate_admin
    before_action :require_account
    before_action :require_admin_account

    private

    def require_admin_account
      head :forbidden unless current_account.admin?
    end

    def authenticate_admin
      username = ENV["ADMIN_USERNAME"]
      password = ENV["ADMIN_PASSWORD"]
      if username.blank? || password.blank?
        head :service_unavailable
        return
      end

      authenticate_or_request_with_http_basic("Commonbound admin") do |given_user, given_password|
        ActiveSupport::SecurityUtils.secure_compare(given_user, username) &
          ActiveSupport::SecurityUtils.secure_compare(given_password, password)
      end
    end

    def prevent_caching
      response.headers["Cache-Control"] = "no-store"
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
    end
  end
end
