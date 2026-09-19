module Admin
  class ContactRequestsController < BaseController
    def index
      @page = [ params[:page].to_i, 1 ].max
      @count = ContactRequest.count
      @requests = ContactRequest.includes(:submission).order(created_at: :desc).offset((@page - 1) * 50).limit(50)
    end

    def show
      @request = ContactRequest.find(params[:id])
    end
  end
end
