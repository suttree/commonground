class SdgsController < ApplicationController
  def index
    @query = params[:q].is_a?(String) ? params[:q].strip.first(120) : ""
    @goal_id = params[:goal].is_a?(String) ? params[:goal] : ""
    @goal_id = "" unless SdgDirectory.goal(@goal_id)
    @searching = @query.present? || @goal_id.present?
    if @searching
      results = SdgDirectory.search(@query, goal_id: @goal_id)
      @count = results.size
      @pages = [ (@count / 18.0).ceil, 1 ].max
      @page = params[:page].to_s.to_i.clamp(1, @pages)
      @results = results.slice((@page - 1) * 18, 18)
    end
  end

  def goal
    @goal = SdgDirectory.goal(params[:id])
    raise ActiveRecord::RecordNotFound unless @goal
    @guide = SdgDirectory::GUIDES.fetch(@goal.fetch("id"))
  end

  def target
    @target = ProfileOptions::TARGETS[params[:id]]
    raise ActiveRecord::RecordNotFound unless @target
    @goal = SdgDirectory.goal(@target.fetch("id").split(".").first)
    @guide = SdgDirectory::GUIDES.fetch(@goal.fetch("id"))
    targets = @goal.fetch("targets")
    position = targets.index(@target)
    @previous = targets[position - 1] if position.positive?
    @next = targets[position + 1]
  end
end
