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
      reply("Мы уже рассматриваем ваше обращение от #{pending_ticket.created_at.strftime('%Y-%m-%d %H:%M')}", reply_markup: nil)
    in "Написать в поддержку"
      current_user.update(state: [self.class.name, "awaiting_input", *state].join("|"))
      msg = <<~TXT
        Напишите ваше обращение в поддержку.
        Вам ответит волонтёр поддержки в личных сообщениях - не закрывайте доступ к ним. 
        Постарайтесь описать свою проблему.
        Отправить можно только одно обращение, но с вами свяжется живой человек - если что-то забыли написать, сообщите ему.
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
        Пользователь #{message.from.first_name} #{message.from.last_name} просит помощи
        Tg_id `#{current_user.tg_id}`:
        Номер: #{support_request.id}
        Статус обращения: #{support_request.status_ru}

        ---
        #{message.text.gsub("---", "***")}
        ---

        #{"Состояние на момент обращения:\n#{state.join("|")}" if state.any?}
      TXT

      actions = SupportRequest::STATUS_RU.keys
                                         .reject { |st| st == support_request.status }
                                         .map do |st|
        label = SupportRequest::STATUS_RU[st]
        { label => callback_name(Admin::SupportRequestsController, "set_status", support_request.id, st) }
      end

      reply_with_inline_buttons(admin_msg, actions, chat_id: $admin_chat_id)

      reply_with_buttons("Ваше обращение (##{support_request.id}) принято. Мы ответим скоро! Пока можете попробовать другую инструкцию.", [["Вернуться в меню"]])
    else
      raise RoutingError
    end
  end

  private

  def pending_ticket
    @pending_ticket ||= current_user.support_requests_dataset
                                    .where(status: [0, 1])
                                    .where { created_at > Sequel::CURRENT_TIMESTAMP - 7*24*60*60 } # 1 week
                                    .first
  end
end