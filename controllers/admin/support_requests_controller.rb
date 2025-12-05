class Admin::SupportRequestsController < Admin::BaseController
  # TODO: this thing must verify if the support ticket is open before proceeding with any changes
  include Admin::UserManagement

  def is_authorized?
    authorized = (chat_id == Bot::ADMIN_CHAT_ID &&
      SupportRequest.where(status: [0, 1], message_thread_id:).first)
    
    unless authorized
      edit_message("Это обращение уже закрыто: действия недоступны.")
    end

    authorized
  end
end
