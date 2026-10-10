class DirectoriesController < ApplicationController
  def people
    directory("person")
  end

  def companies
    directory("organisation")
  end

  private

  def directory(kind)
    @company = kind == "organisation"
    @query = params[:q].to_s.strip.first(200)
    @location = params[:location].to_s.strip.first(200)
    @skill = params[:skill].to_s.strip.first(200)
    @sector = params[:sector].to_s
    @goal = params[:goal].to_s
    @target = params[:target].to_s
    profiles = Submission.published.where(kind: kind)
    name_column = @company ? :organisation_name : :name
    profiles = profiles.where("#{name_column} LIKE ?", "%#{Submission.sanitize_sql_like(@query)}%") if @query.present?
    profiles = profiles.where("location LIKE ?", "%#{Submission.sanitize_sql_like(@location)}%") if @location.present?
    if @skill.present?
      profiles = profiles.where("EXISTS (SELECT 1 FROM json_each(submissions.profile, '$.skills') WHERE LOWER(TRIM(json_extract(value, '$.skill'))) = LOWER(?))", @skill)
    end
    if @sector.present?
      profiles = profiles.where("EXISTS (SELECT 1 FROM json_each(submissions.profile, '$.sectors_past') WHERE value = ?) OR EXISTS (SELECT 1 FROM json_each(submissions.profile, '$.sectors_future') WHERE value = ?)", @sector, @sector)
    end
    if @goal.present?
      profiles = profiles.where("EXISTS (SELECT 1 FROM json_each(submissions.profile, '$.target_ids') WHERE value LIKE ?)", "#{Submission.sanitize_sql_like(@goal)}.%")
    end
    if @target.present?
      profiles = profiles.where("EXISTS (SELECT 1 FROM json_each(submissions.profile, '$.target_ids') WHERE value = ?)", @target)
    end
    @count = profiles.count
    @page = [ params[:page].to_i, 1 ].max
    @profiles = profiles.order(name_column, :id).limit(24).offset((@page - 1) * 24)
    render :index
  end
end
