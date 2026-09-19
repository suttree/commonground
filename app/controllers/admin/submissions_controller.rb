module Admin
  class SubmissionsController < BaseController
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
      if @submission.update(params.require(:submission).permit(:status, :notes, :published, :exploring, target_ids: []))
        redirect_to admin_submission_path(@submission), notice: "Review saved.", status: :see_other
      else
        render :show, status: :unprocessable_entity
      end
    end

    def image
      image = PortfolioImage.where.not(submission_id: nil).find(params[:id])
      response.headers["X-Content-Type-Options"] = "nosniff"
      send_data image.data, type: image.content_type, disposition: "inline"
    end
  end
end
