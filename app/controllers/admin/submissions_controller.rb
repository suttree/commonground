module Admin
  class SubmissionsController < ApplicationController
    before_action :authenticate_admin
    before_action :prevent_caching

    def index
      @kind = params[:kind].presence_in(Submission::KINDS)
      @status = params[:status].presence_in(Submission::STATUSES)
      scope = Submission.order(created_at: :desc)
      scope = scope.where(kind: @kind) if @kind
      scope = scope.where(status: @status) if @status
      @count = scope.count
      @page = [ params[:page].to_i, 1 ].max
      @submissions = scope.offset((@page - 1) * 50).limit(50)
    end

    def show
      @submission = Submission.find(params[:id])
    end

    def update
      @submission = Submission.find(params[:id])
      if @submission.update(params.require(:submission).permit(:status, :notes))
        redirect_to admin_submission_path(@submission), notice: "Review saved.", status: :see_other
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

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
