# frozen_string_literal: true

class Admin::SupportRequestsController < Admin::BaseController
  include Admin::UserManagement

  def is_authorized?
    chat_id == Bot::ADMIN_CHAT_ID &&
      SupportRequest.where(status: [0, 1], message_thread_id:).first
  end
end
