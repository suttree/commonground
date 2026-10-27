class ProvocationAnswersController < ApplicationController
  PAGE_SIZE = 10

  before_action :require_account
  before_action :find_profile

  def index
    @answer_count = @profile.provocation_answers.count
    @total_pages = [ (@answer_count.to_f / PAGE_SIZE).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @answers = @profile.provocation_answers.includes(:provocation)
      .order(created_at: :desc, id: :desc).limit(PAGE_SIZE).offset((@page - 1) * PAGE_SIZE)
  end

  def create
    provocation = Provocation.visible.find(params[:provocation_id])
    answer = @profile.provocation_answers.find_or_initialize_by(provocation: provocation)
    if provocation.status == "retired" && answer.new_record?
      raise ActiveRecord::RecordNotFound
    end
    answer.assign_attributes(params.permit(:choice, :note, :shared, :allow_introductions))
    if answer.save
      redirect_to answer_return_path, notice: "Answer saved.", status: :see_other
    else
      redirect_to answer_return_path, alert: answer.errors[:note].any? ? "Keep your note to 2,000 characters or fewer." : "Choose one of the four answers.", status: :see_other
    end
  end
  def destroy
    @profile.provocation_answers.find(params[:id]).destroy!
    redirect_to profile_provocation_answers_path(@profile.public_slug), notice: "Answer and note deleted.", status: :see_other
  end

  private

  def find_profile
    @profile = current_account.submissions.find_by!(public_slug: params[:slug], kind: "person")
  end

  def answer_return_path
    if params[:return_to_provocation].present?
      provocation_path(params[:provocation_id])
    elsif params[:history_page].present?
      profile_provocation_answers_path(@profile.public_slug, page: [ params[:history_page].to_i, 1 ].max)
    else
      dashboard_path(anchor: "provocations")
    end
  end
end
