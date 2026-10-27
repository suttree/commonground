module Admin
  class ProvocationsController < BaseController
    before_action :find_provocation, only: [ :edit, :update, :revise ]

    def index
      @provocations = Provocation.in_order
    end

    def new
      @provocation = Provocation.new(status: "draft", position: (Provocation.maximum(:position) || 0) + 1)
    end

    def create
      @provocation = Provocation.new(provocation_params.merge(key: SecureRandom.uuid))
      if @provocation.save
        redirect_to admin_provocations_path, notice: "Question created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @provocation.update(provocation_params)
        redirect_to admin_provocations_path, notice: "Question updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def revise
      revision = @provocation.dup
      revision.assign_attributes(key: SecureRandom.uuid, status: "draft")
      revision.save!
      redirect_to edit_admin_provocation_path(revision), notice: "Draft revision created. Retire the original when you publish its replacement."
    end

    private

    def find_provocation
      @provocation = Provocation.find(params[:id])
    end

    def provocation_params
      params.require(:provocation).permit(:question, :goal_id, :position, :status)
    end
  end
end
