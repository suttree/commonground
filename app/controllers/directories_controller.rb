class DirectoriesController < ApplicationController
  before_action -> { require_account_for_search(%i[q location skill sector goal target priorities]) }

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
    @use_priorities = params[:priorities] == "1"
    targets = if current_account && current_account.onboarding.present? && !current_account.submissions.exists?(kind: "person")
      current_account.onboarding["target_ids"]
    elsif current_profile
      current_profile.target_ids
    else
      session[:confirmed_quiz_targets]
    end
    @priority_goals = @use_priorities ? Array(targets).select { |id| ProfileOptions::TARGETS.key?(id) }.map { |id| id.split(".").first }.uniq : []
    profiles = Submission.published.where(kind: kind)
    if @priority_goals.any?
      conditions = @priority_goals.map { "EXISTS (SELECT 1 FROM json_each(submissions.profile, '$.target_ids') WHERE value LIKE ?)" }.join(" OR ")
      profiles = profiles.where(conditions, *@priority_goals.map { |id| "#{id}.%" })
    end
    name_column = @company ? :organisation_name : :name
    profiles = profiles.where("#{name_column} LIKE ?", "%#{Submission.sanitize_sql_like(@query)}%") if @query.present?
    profiles = profiles.where("location LIKE ?", "%#{Submission.sanitize_sql_like(@location)}%") if @location.present?
    if @skill.present?
      profiles = profiles.where("EXISTS (SELECT 1 FROM json_each(submissions.profile, '$.skills') WHERE LOWER(TRIM(json_extract(value, '$.skill'))) = LOWER(?)) OR LOWER(json_extract(submissions.profile, '$.skills_summary')) LIKE LOWER(?)", @skill, "%#{Submission.sanitize_sql_like(@skill)}%")
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
