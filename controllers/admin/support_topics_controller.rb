class Admin::SupportTopicsController < Admin::BaseController
  def call
    if message.forum_topic_reopened
      reply("Закрытые обращения нельзя переоткрыть.", message_thread_id:)
    elsif message.forum_topic_closed
      if request.nil?
        reply("Это обращение уже было закрыто.", message_thread_id:)
      else
        rename_closed_topic
      end
    elsif message_thread_id
      if request.nil?
        reply("Это обращение уже было закрыто.", message_thread_id:)
      else
        unless request.user.state_array in ["SupportTopicsController", *]
          reply_with_buttons("Новое сообщение от поддержки:", [["Вернуться в меню"]], chat_id: request.chat_id)
        end

        request.user.update(state: ["SupportTopicsController"].join("|"))
        repeat_message(chat_id: request.chat_id)
      end
    end
  end

  private

  def request
    @support_request ||= SupportRequest.where(status: 0, message_thread_id:)
                                       .first
  end

  def message_thread_id
    @message_thread_id ||= message.reply_to_message.message_thread_id
  end

  def rename_closed_topic
    request.closed!
    request.save
    res = bot.api.call("editForumTopic", {
      chat_id: $admin_chat_id,
      message_thread_id:,
      name: "🟢 - Обращение №#{request.id}"
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
