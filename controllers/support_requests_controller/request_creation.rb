# frozen_string_literal: true

module SupportRequestsController::RequestCreation
  private

  def create_support_request(state)
    2.times { state.shift }

    current_user.update(state: [self.class.name, "input_received", *state].join("|"))
    reply("Подождите: передаём ваше сообщение в поддержку.", reply_markup: nil)

    close_abandoned_requests
    support_request = current_user.add_support_request(status: 0)

    thread_id = create_thread(support_request)
    add_messages_to_thread(support_request, state, thread_id)

    current_user.update(state: [self.class.name, "input_forwarded", *state].join("|"))
    reply_with_buttons("Ваше обращение (##{support_request.id}) принято. Мы ответим скоро!", [["Вернуться в меню"]])
  rescue StandardError => e
    LOGGER.error "Failed to create support request: #{e.class}"

    DB.transaction do
      current_user.update(state: [self.class.name, "awaiting_input", *state].join("|"))
      support_request.update(status: 2)
    end

    reply("Не получилось передать сообщение в поддержку. Попробуйте ещё раз", reply_markup: nil)

    if thread_id
      reply("🤖: Это обращение закрыто из-за внутренней ошибки: #{e.class}", chat_id: Bot::ADMIN_CHAT_ID, message_thread_id: thread_id)
    end

    raise
  end

  def close_abandoned_requests
    requests = current_user.support_requests_dataset
                           .where(status: 0)
                           .where { updated_at > Sequel.lit("datetime(CURRENT_TIMESTAMP, '-3 days')") }
    requests.update(status: 2)

    requests.each do |request|
      thread_id = request.message_thread_id

      msg = "Это обращение было закрыто в связи с новым обращением пользователя."
      reply(msg, chat_id: Bot::ADMIN_CHAT_ID, message_thread_id: thread_id)
      request.set_close!
      bot.api.call("closeForumTopic", {
        chat_id: Bot::ADMIN_CHAT_ID,
        message_thread_id: thread_id
      })
    rescue Telegram::Bot::Exceptions::ResponseError => e
      case e.data["description"]
      in /TOPIC_NOT_MODIFIED/
        LOGGER.warn "Topic #{request.id} was not modified by #{__method__} in #{self.class}"
      in /message thread not found/
        LOGGER.warn "Topic is missing for request №#{request.id}: closing request."
        request.closed!
        request.save
      else
        raise
      end
    end
  end

  def create_thread(support_request)
    res = bot.api.call("createForumTopic", {
       chat_id: Bot::ADMIN_CHAT_ID,
       name: "Обращение №#{support_request.id}",
       icon_custom_emoji_id: 5377316857231450742
     })

    thread_id = res["result"]["message_thread_id"]
    support_request.update(message_thread_id: thread_id)

    thread_id
  end

  def add_messages_to_thread(support_request, state, thread_id)
    admin_msg = compose_admin_msg(support_request, state)
    reply(admin_msg, chat_id: Bot::ADMIN_CHAT_ID, message_thread_id: thread_id, parse_mode: "MarkdownV2")

    res = reply_with_inline_buttons(*user_menu_args, chat_id: Bot::ADMIN_CHAT_ID, message_thread_id: thread_id, parse_mode: "MarkdownV2")
    support_request.update(user_menu_message_id: res.message_id)
  end

  def compose_admin_msg(support_request, state)
    admin_msg = <<~TXT.strip
      Номер обращения: #{support_request.id}
      User ID: `#{current_user.id}`

      #{message.text[0..3072].split("\n").map { |l| ">#{escape_md_v2(l.strip)}" }.join("\n")}
    TXT

    if state.any?
      admin_msg << "\n\nСостояние на момент обращения:\n#{"_#{escape_md_v2(state.join("|"))}_"}"
    end

    admin_msg
  end

  def user_menu_args
    [
      "Нажмите сюда, чтобы управлять ключами",
      {
        "Управление ключами" => callback_name(Admin::SupportRequestsController, "user_menu", current_user.id)
      }
    ]
  end
end
