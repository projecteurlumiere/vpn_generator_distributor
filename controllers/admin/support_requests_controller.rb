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

    edited_msg = reconstruct_request_ticket(edited_msg)

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
      parse_mode: "MarkdownV2",
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

  private

  # this atrocity exists because TG won't allow us to edit markdown messages
  # it just sends plain text messages
  def reconstruct_request_ticket(str)
    str.split("\n") => [
      name,
      tg_id,
      request_id,
      status,
      "",
      *quote
    ]

    quote in [*quote, "", /^Состояние на момент обращения:/, state]

    name       = name.sub(/^Пользователь /, "").sub(/ просит помощи$/, "").strip
    tg_id      = tg_id.sub(/^Tg id: /i, "").strip
    request_id = request_id.sub(/^Номер: /, "").strip

    msg = [
      "Пользователь [#{escape_md_v2(name)}](tg://user?id=#{tg_id}) просит помощи",
      "Tg id: `#{tg_id}`",
      "Номер: #{request_id}",
      status, # precooked
      "",
      quote.map { |line| ">#{escape_md_v2(line.strip)}" }.join("\n")
    ]

    if state
      msg << ""
      msg << "Состояние на момент обращения:"
      msg << escape_md_v2(state)
    end

    msg.join("\n")
  end
end
