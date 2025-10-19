class SupportRequestsController < ApplicationController
  def self.routes
    ["Написать в поддержку"]
  end

  def call
    if $admin_chat_id.nil?
      reply("Сейчас обратиться в поддержку нельзя. Попробуйте позже. Извините!", reply_markup: nil)
      return
    end

    state = current_user.state_array

    case message.text
    in "Написать в поддержку" if pending_request
      msg = <<~TXT
        Мы уже рассматриваем ваше обращение №#{pending_request.id} от #{pending_request.created_at.strftime("%Y-%m-%d %H:%M")}

        Если с вами не связались в течение трёх суток, вы сможете отправить новый запрос.
      TXT

      reply(msg, reply_markup: nil)
    in "Написать в поддержку"
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
        admin_msg << "\n\nСостояние на момент обращенияv:\n#{"_#{escape_md_v2(state.join("|"))}_"}"
      end

      actions = [
        # "Закрыть",
        "Управление ключами" => callback_name(Admin::SupportRequestsController, "user_menu", current_user.id)
      ]

      emoji = ["😎", "🎉", "🥳", "🚀", "🌟", "🤖"].sample

      res = bot.api.call("createForumTopic", {
        chat_id: $admin_chat_id,
        name: "#{emoji} - Обращение №#{support_request.id}"
      })
      message_thread_id = res["result"]["message_thread_id"]
      support_request.update(message_thread_id:)
      reply(admin_msg, chat_id: $admin_chat_id, message_thread_id:, parse_mode: "MarkdownV2")
      reply_with_inline_buttons("Нажмите сюда, чтобы управлять ключами", actions, chat_id: $admin_chat_id, message_thread_id:, parse_mode: "MarkdownV2")

      reply_with_buttons("Ваше обращение (##{support_request.id}) принято. Мы ответим скоро! Пока можете попробовать другую инструкцию.", [["Вернуться в меню"]])
    else
      raise RoutingError
    end
  end

  private

  def pending_request
    @pending_request ||= current_user.support_requests_dataset
      .where(status: 0)
      .where { created_at > Sequel.expr(Sequel::CURRENT_TIMESTAMP) - Sequel.lit("interval '3 days'") }
      .first
  end

  def close_abandoned_requests
    requests = current_user.support_requests_dataset
                           .where(status: 0)
                           .where { created_at <= Sequel.expr(Sequel::CURRENT_TIMESTAMP) - Sequel.lit("interval '3 days'") }
    requests.each do |request|
      message_thread_id = request.message_thread_id

      msg = "Это обращение было закрыто в связи с новым обращением пользователя."
      reply(msg, chat_id: $admin_chat_id, message_thread_id:)

      bot.api.call("closeForumTopic", {
        chat_id: $admin_chat_id,
        message_thread_id:
      })
      sleep 1
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
