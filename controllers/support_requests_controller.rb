# frozen_string_literal: true

class SupportRequestsController < ApplicationController
  include SupportRequestsController::RequestCreation

  def self.routes
    ["Написать в поддержку", "Задать вопрос"]
  end

  def call
    if Bot::ADMIN_CHAT_ID.nil?
      msg = "Сейчас обратиться в поддержку нельзя. Попробуйте позже. Извините!"
      reply(msg, reply_markup: nil)
      return
    end

    # [controller_name, state_within_controller, *previous_state]
    state = current_user.state_array

    case message.text
    in ("Написать в поддержку" | "Задать вопрос") if unread_request
      reply_request_is_unread
    in ("Написать в поддержку" | "Задать вопрос") if open_request
      redirect_to_current_request(state)
    in ("Написать в поддержку" | "Задать вопрос")
      reply_new_request(state)
    in "Назад"
      restore_previous_state(state.drop(2))
    else
      process_state(state)
    end
  end

  private

  def unread_request
    @pending_request ||= current_user.support_requests_dataset
                                     .where(status: [0])
                                     .where { updated_at > Sequel.lit("datetime(CURRENT_TIMESTAMP, '-3 days')") }
                                     .first
  end

  def reply_request_is_unread
    msg = <<~TXT
      Мы уже рассматриваем ваше обращение №#{unread_request.id} от #{unread_request.created_at.strftime("%Y-%m-%d %H:%M")}

      Если с вами не связались в течение трёх суток, вы сможете отправить новый запрос.
    TXT

    reply(msg, reply_markup: nil)
  end

  def open_request
    @open_request ||= current_user.support_requests_dataset
                                  .where(status: 1)
                                  .first
  end

  def redirect_to_current_request(state)
    current_user.update(state: ["SupportTopicsController", *state].join("|"))
    msg = <<~TXT
      Вы уже общаетесь с поддержкой. Напишите ваше сообщение, и волонтёры сразу получат его.
    TXT

    reply_with_buttons(msg, [["Вернуться в меню"]])
  end

  def reply_new_request(state)
    current_user.update(state: [self.class.name, "awaiting_input", *state].join("|"))
    reply_slide(:support, input_field_placeholder: nil)
  end

  def restore_previous_state(prev_state) # arg is previous state!
    case prev_state
    in ["InstructionsController", *]
      InstructionsController.new(bot, message).send(:reply_with_instructions, "Выберите ваше устройство")
    else
      StartController.new(bot, message).send(:reply_menu)
    end
  end

  def process_state(state)
    case state[1]
    in "input_received"
      msg = "Подождите. Мы уже передаём ваше сообщение в поддержку."
      reply(msg, reply_markup: nil)
    in "input_forwarded"
      msg = "Мы уже передали ваше сообщение в поддержку."
      reply_with_buttons(msg, [["Назад"]], reply_markup: nil)
    in "awaiting_input" if message.text.nil?
      reply("Пожалуйста, пришлите текстовое сообщение.", reply_markup: nil)
    in "awaiting_input"
      create_support_request(state) # see SupportRequestsController::RequestCreation
    else
      raise RoutingError
    end
  end
end
