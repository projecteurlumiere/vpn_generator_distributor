class Admin::BaseController < ApplicationController
  def is_authorized?
    current_user.admin?
  end

  def concerns_open_support_request?
    chat_id == Bot::ADMIN_CHAT_ID &&
      message_thread_id &&
      SupportRequest.where(status: [0, 1], message_thread_id:).first
  end

  def admin_menu_inline_button
    {
      "В меню" => callback_name(Admin::MenuController, "menu")
    }
  end
end
