# frozen_string_literal: true

class Admin::SupportTopicsController < Admin::BaseController
  def is_authorized?
    chat_id == Bot::ADMIN_CHAT_ID && concerns_support_request?
  end

  # No RoutingError is raised: we don't want to pollute Admin Chat
  def call
    if message.forum_topic_reopened
      reply("Закрытые обращения нельзя переоткрыть.")
    elsif message.forum_topic_closed && request
      request.set_closed!(bot)
      edit_message("Это обращение было закрыто: действия недоступны.", chat_id:, message_id: request.user_menu_message_id)

      msg = "Ваше обращение в поддержку №#{request.id} от #{request.created_at.strftime("%Y-%m-%d %H:%M")} было помечено как рассмотренное"
      reply_with_buttons(msg,
        [["Вернуться в меню"]],
        chat_id: request.user.chat_id,
        message_thread_id: nil
      )
    elsif request.nil? && !message.text.nil?
      reply("Это обращение уже было закрыто.")
    elsif !message.text.nil?
      unless request.user.state_array in ["SupportTopicsController", *]
        reply_with_buttons("Новое сообщение от поддержки:", [["Вернуться в меню"]], chat_id: request.user.chat_id, message_thread_id: nil)
      end

      request.set_open!(bot)
      repeat_message(chat_id: request.user.chat_id)
    end
  end

  private

  def concerns_support_request?
    message_thread_id && (SupportRequest.where(message_thread_id:).first || message.forum_topic_created)
  end

  def request
    @support_request ||= SupportRequest.where(status: [0, 1], message_thread_id:)
                                       .first
  end
end
