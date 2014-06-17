class BulkUpdateRequestsController < ApplicationController
  respond_to :html, :xml, :json
  before_filter :member_only
  before_filter :admin_only, :only => [:update]

  def new
    @bulk_update_request = BulkUpdateRequest.new(:user_id => CurrentUser.user.id)
    respond_with(@bulk_update_request)
  end

  def create
    @bulk_update_request = BulkUpdateRequest.create(params[:bulk_update_request])
    respond_with(@bulk_update_request, :location => bulk_update_requests_path)
  end

  def update
    @bulk_update_request = BulkUpdateRequest.find(params[:id])
    if params[:status] == "approved"
      @bulk_update_request.approve!
    else
      @bulk_update_request.reject!
    end
    flash[:notice] = "Bulk update request updated"
    respond_with(@bulk_update_request, :location => bulk_update_requests_path)
  end

  def index
    @bulk_update_requests = BulkUpdateRequest.order("(case status when 'pending' then 0 when 'approved' then 1 else 2 end), id desc").paginate(params[:page], :limit => params[:limit])
    respond_with(@bulk_update_requests)
  end
end