class SupportRequestsController < ApplicationController
  def self.routes
    ["Написать в поддержку", "Задать вопрос"]
  end

  def call
    if Bot::ADMIN_CHAT_ID.nil?
      reply("Сейчас обратиться в поддержку нельзя. Попробуйте позже. Извините!", reply_markup: nil)
      return
    end

    state = current_user.state_array

    case message.text
    in ("Написать в поддержку" | "Задать вопрос") if unread_request
      msg = <<~TXT
        Мы уже рассматриваем ваше обращение №#{unread_request.id} от #{unread_request.created_at.strftime("%Y-%m-%d %H:%M")}

        Если с вами не связались в течение трёх суток, вы сможете отправить новый запрос.
      TXT

      reply(msg, reply_markup: nil)
    in ("Написать в поддержку" | "Задать вопрос") if open_request
      current_user.update(state: ["SupportTopicsController", *state].join("|"))
      msg = <<~TXT
        Вы уже общаетесь с поддержкой. Напишите ваше сообщение, и волонтёры сразу получат его.
      TXT

      reply_with_buttons(msg, [["Вернуться в меню"]])
    in ("Написать в поддержку" | "Задать вопрос")
      current_user.update(state: [self.class.name, "awaiting_input", *state].join("|"))

      msg = <<~TXT
        Напишите ваше обращение в поддержку. Постарайтесь описать свою проблему.
        В течение трёх дней волонтёр из нашей команды напишет вам в личные сообщения.
        Не закрывайте доступ к ним иначе мы не сможем к вам дописаться!

        Отправить можно только одно обращение.
        Если в течение трёх суток вы не получили ответа, вы сможете отправить ещё одно обращение.
      TXT

      reply_with_buttons(msg, [["Назад"]])
    in "Назад"
      2.times { state.shift }

      case state
      in ["InstructionsController", *]
        state[2] = state[2].to_i - 1 unless state[2].to_i.zero? # step
        current_user.update(state: state.join("|"))
        InstructionsController.new(bot, message).call
      else
        StartController.new(bot, message).send(:reply_menu)
      end
    in String if state[0] == self.class.name && state[1] == "input_received"
      reply("Подождите. Мы уже передаём ваше сообщение в поддержку.", reply_markup: nil)
    in String if state[0] == self.class.name && state[1] == "input_forwarded"
      reply_with_buttons("Мы уже передали ваше сообщение в поддержку.", [["Назад"]], reply_markup: nil)
    in String if state[0] == self.class.name && state[1] == "awaiting_input"
      create_support_request(state)
    else
      raise RoutingError
    end
  end

  private

  def unread_request
    @pending_request ||= current_user.support_requests_dataset
      .where(status: [0, 1])
      .where { updated_at > Sequel.lit("datetime(CURRENT_TIMESTAMP, '-3 days')") }
      .first
  end

  def open_request
    @open_request ||= current_user.support_requests_dataset
                                  .where(status: 1)
                                  .first
  end

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

    reply_with_buttons("Не получилось передать сообщение в поддержку. Попробуйте ещё раз", reply_markup: nil)

    if thread_id
      reply("🤖: Это обращение закрыто из-за внутренней ошибки: #{e.class}", chat_id: Bot::ADMIN_CHAT_ID, message_thread_id: thread_id)
    end

    raise
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
      [
        "Управление ключами" => callback_name(Admin::SupportRequestsController, "user_menu", current_user.id)
      ]
    ]
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
end
