class ProvocationsController < ApplicationController
  def show
    response.headers["Cache-Control"] = "no-store"
    @provocation = Provocation.visible.find(params[:id])
    @profile = current_account&.submissions&.find_by(kind: "person")
    @answer = @profile&.provocation_answers&.find_by(provocation: @provocation)
    if current_account
      @show_results = @answer.present? || params[:results] == "1"
      @distribution = @provocation.provocation_answers.shared.group(:choice).count if @show_results
      notes = @provocation.provocation_answers.shared.with_notes
      total_pages = [ (notes.count / 20.0).ceil, 1 ].max
      @page = params[:page].to_i.clamp(1, total_pages)
      @notes = notes.includes(submission: :account).order(created_at: :desc, id: :desc)
        .limit(21).offset((@page - 1) * 20)
    end
  end
end
