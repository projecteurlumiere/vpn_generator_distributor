class Admin::SupportRequestsController < Admin::BaseController
  # TODO: this thing must verify if the support ticket is open before proceeding with any changes
  include Admin::UserManagement
end
