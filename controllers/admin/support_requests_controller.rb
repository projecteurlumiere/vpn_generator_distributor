class Admin::SupportRequestsController < ApplicationController
  def self.routes
    []
  end

  def set_status(id, status)
    support_request = SupportRequest[id]
    support_request.update(status: status.to_sym)

    edited_msg = message.message
                        .text
                        .sub(/^Статус обращения.*$/i, "Статус обращения: #{support_request.status_ru}")

    actions = SupportRequest::STATUS_RU.keys
                                       .reject { |st| st == support_request.status }
                                       .map do |st|
      label = SupportRequest::STATUS_RU[st]
      { label => callback_name(Admin::SupportRequestsController, "set_status", support_request.id, st) }
    end

    bot.api.edit_message_text(
      chat_id: message.message.chat.id,
      message_id: message.message.message_id,
      text: edited_msg,
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: actions.map do |btn|
          btn.map do |text, callback_data|
            Telegram::Bot::Types::InlineKeyboardButton.new(text: text, callback_data: callback_data)
          end
        end
      )
    )
  rescue StandardError => e
    LOGGER.error("Error when setting ticket's status. #{e.class}: #{e.message}")
  end
end
