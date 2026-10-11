class SideProjectsController < ApplicationController
  before_action :require_account
  before_action :check_profile_id
  before_action :find_profile
  before_action :find_project, only: %i[edit update destroy]

  def new
    @side_project = @profile.side_projects.new
  end

  def create
    @side_project = @profile.side_projects.new(project_params)
    save_project(:new)
  end

  def edit
  end

  def update
    @side_project.assign_attributes(project_params)
    save_project(:edit)
  end

  def destroy
    @side_project.destroy!
    redirect_to editor_path, notice: "Side project removed.", status: :see_other
  end

  private

  def find_profile
    @profile = current_profile
    raise ActiveRecord::RecordNotFound unless @profile && !@profile.organisation?
  end

  def find_project
    @side_project = @profile.side_projects.find(params[:id])
  end

  def project_params
    params.require(:side_project).permit(:name, :description, :purpose, :joy, :url)
  end

  def editor_path
    edit_account_profile_path(section: "side_projects", profile_id: @profile.id)
  end

  def save_project(template)
    uploads = Array(params[:photos]).reject(&:blank?)
    remove_ids = Array(params[:remove_photo_ids]).map(&:to_i)
    existing = @side_project.photos.to_a
    raise ActiveRecord::RecordNotFound unless (remove_ids - existing.map(&:id)).empty?
    kept = existing.reject { |photo| remove_ids.include?(photo.id) }
    cover_id = params[:cover_image_id].presence&.to_i
    raise ActiveRecord::RecordNotFound if cover_id && !existing.any? { |photo| photo.id == cover_id }
    @side_project.valid?
    @side_project.errors.add(:photos, "must contain no more than five images") if kept.size + uploads.size > 5
    if @side_project.errors.any?
      return render template, status: :unprocessable_entity
    end
    SideProject.transaction do
      @side_project.cover_image_id = kept.any? { |photo| photo.id == cover_id } ? cover_id : kept.first&.id
      @side_project.save!
      uploads.each do |upload|
        image = PortfolioImage.stage(upload, session[:portfolio_upload_key] ||= SecureRandom.hex(24))
        image.update!(submission: @profile, side_project: @side_project)
      end
      @side_project.photos.where(id: remove_ids).destroy_all
    end
    redirect_to editor_path, notice: "Side project saved.", status: :see_other
  rescue ArgumentError => error
    @side_project.errors.add(:photos, error.message)
    render template, status: :unprocessable_entity
  end
end
