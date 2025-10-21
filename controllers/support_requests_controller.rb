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
    in String if state[0] == self.class.name && state[1] == "awaiting_input"
      2.times { state.shift }

      close_abandoned_requests
      support_request = current_user.add_support_request(status: 0, chat_id:)

      admin_msg = <<~TXT.strip
        Номер обращения: #{support_request.id}
        User ID: `#{current_user.id}`

        #{message.text[0..3072].split("\n").map { |l| ">#{escape_md_v2(l.strip)}" }.join("\n")}
      TXT

      if state.any?
        admin_msg << "\n\nСостояние на момент обращения:\n#{"_#{escape_md_v2(state.join("|"))}_"}"
      end

      actions = [
        # "Закрыть",
        "Управление ключами" => callback_name(Admin::SupportRequestsController, "user_menu", current_user.id)
      ]

      res = bot.api.call("createForumTopic", {
        chat_id: Bot::ADMIN_CHAT_ID,
        name: "Обращение №#{support_request.id}",
        icon_custom_emoji_id: 5377316857231450742
      })

      thread_id = res["result"]["message_thread_id"]
      support_request.update(message_thread_id: thread_id)
      reply(admin_msg, chat_id: Bot::ADMIN_CHAT_ID, message_thread_id: thread_id, parse_mode: "MarkdownV2")
      reply_with_inline_buttons("Нажмите сюда, чтобы управлять ключами", actions, chat_id: Bot::ADMIN_CHAT_ID, message_thread_id: thread_id, parse_mode: "MarkdownV2")

      reply_with_buttons("Ваше обращение (##{support_request.id}) принято. Мы ответим скоро! Пока можете попробовать другую инструкцию.", [["Вернуться в меню"]])
    else
      raise RoutingError
    end
  end

  private

  def unread_request
    @pending_request ||= current_user.support_requests_dataset
      .where(status: [0, 1])
      .where { updated_at > Sequel.expr(Sequel::CURRENT_TIMESTAMP) - Sequel.lit("interval '3 days'") }
      .first
  end

  def open_request
    @open_request ||= current_user.support_requests_dataset
                                  .where(status: 1)
                                  .first
  end

  def close_abandoned_requests
    requests = current_user.support_requests_dataset
                           .where(status: 0)
                           .where { updated_at <= Sequel.expr(Sequel::CURRENT_TIMESTAMP) - Sequel.lit("interval '3 days'") }
    requests.each do |request|
      thread_id = request.message_thread_id

      msg = "Это обращение было закрыто в связи с новым обращением пользователя."
      reply(msg, chat_id: Bot::ADMIN_CHAT_ID, message_thread_id: thread_id)

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
        raise e
      end
    end
  end
end
