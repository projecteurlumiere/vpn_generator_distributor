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
    in "Написать в поддержку" if pending_ticket
      msg = <<~TXT
        Мы уже рассматриваем ваше обращение от #{pending_ticket.created_at.strftime("%Y-%m-%d %H:%M")}

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

      support_request = current_user.add_support_request(status: 0)

      admin_msg = <<~TXT.strip
        Пользователь [#{escape_md_v2([message.from.first_name, message.from.last_name].compact.join(" "))}](tg://user?id=#{current_user.tg_id}) просит помощи
        Tg id: `#{current_user.tg_id}`
        Номер: #{support_request.id}
        Статус обращения: #{support_request.status_ru}

        #{message.text[0..3072].split("\n").map { |l| ">#{escape_md_v2(l.strip)}" }.join("\n")}
      TXT

      if state.any?
        admin_msg << "\n\nСостояние на момент обращения:\n#{"_#{escape_md_v2(state.join("|"))}_"}"
      end

      actions = SupportRequest::STATUS_RU.keys
                                         .reject { |st| st == support_request.status }
                                         .map do |st|
        label = SupportRequest::STATUS_RU[st]
        { label => callback_name(Admin::SupportRequestsController, "set_status", support_request.id, st) }
      end

      reply_with_inline_buttons(admin_msg, actions, chat_id: $admin_chat_id, parse_mode: "MarkdownV2")

      reply_with_buttons("Ваше обращение (##{support_request.id}) принято. Мы ответим скоро! Пока можете попробовать другую инструкцию.", [["Вернуться в меню"]])
    else
      raise RoutingError
    end
  end

  private

  def pending_ticket
    @pending_ticket ||= current_user.support_requests_dataset
                                    .where(status: [0, 1])
                                    .where { created_at > Sequel::CURRENT_TIMESTAMP - 3*24*60*60 } # 3 days
                                    .first
  end
end
