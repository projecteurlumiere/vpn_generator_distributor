class Admin::SupportTopicsController < Admin::BaseController
  def call
    return unless concerns_request_topic?

    if message.forum_topic_reopened
      reply("Закрытые обращения нельзя переоткрыть.", message_thread_id:)
    elsif message.forum_topic_closed
      if request.nil?
        reply("Это обращение уже было закрыто.", message_thread_id:)
      else
        close_topic
      end
    elsif request.nil?
      reply("Это обращение уже было закрыто.", message_thread_id:)
    elsif !message.text.nil?
      unless request.user.state_array in ["SupportTopicsController", *]
        reply_with_buttons("Новое сообщение от поддержки:", [["Вернуться в меню"]], chat_id: request.chat_id)
      end

      if request.unread?
        begin
          bot.api.call("editForumTopic", {
            chat_id: $admin_chat_id,
            message_thread_id:,
            name: "Обращение №#{request.id}",
            icon_custom_emoji_id: 5238156910363950406
          })
        rescue Telegram::Bot::Exceptions::ResponseError => e
          case e.data["description"]
          in /TOPIC_NOT_MODIFIED/
            LOGGER.warn "Topic #{request.id} was not modified by #{__method__} in #{self.class}"
          else
            raise e
          end
        end
      end

      DB.transaction do
        request.user.update(state: ["SupportTopicsController"].join("|"))
        request.open! if request.unread?
        request.update(updated_at: Time.now)
        request.save
      end

      repeat_message(chat_id: request.chat_id)
    end
  end

  private

  def concerns_request_topic?
    message_thread_id && SupportRequest.where(message_thread_id:).first
  end

  def request
    @support_request ||= SupportRequest.where(status: [0, 1], message_thread_id:)
                                       .first
  end

  def message_thread_id
    @message_thread_id ||= message.reply_to_message&.message_thread_id
  end

  def close_topic
    request.closed!
    request.save

    res = bot.api.call("editForumTopic", {
      chat_id: $admin_chat_id,
      message_thread_id:,
      name: "Обращение №#{request.id}",
      icon_custom_emoji_id: 5237699328843200968
    })

    msg = "Ваше обращение в поддержку №#{request.id} от #{request.created_at.strftime("%Y-%m-%d %H:%M")} было помечено как рассмотренной"
    reply_with_buttons(msg,
      [["Вернуться в меню"]],
      chat_id: request.chat_id
    )
  rescue Telegram::Bot::Exceptions::ResponseError => e
    case e.data["description"]
    in /TOPIC_NOT_MODIFIED/
      LOGGER.warn "Topic #{request.id} was not modified by #{__method__} in #{self.class}"
    in /message thread not found/
      LOGGER.warn "Topic is missing for request №#{request.id}."
    else
      raise e
    end
  end
end
