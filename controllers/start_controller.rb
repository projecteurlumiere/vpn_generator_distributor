class StartController < ApplicationController
  def self.routes
    ["/start", "Ознакомиться с правилами", "Правила подтверждаю", "Инструкции"]
  end

  def call
    current_user.update(state: nil)

    case message.text
    in "/start" if current_user.rules_read
      reply_instructions
    in "Инструкции"
      reply_instructions
    in "/start"
      reply_welcome
    in "Ознакомиться с правилами"
      reply_rules
    in "Правила подтверждаю"
      current_user.update(rules_read: true)
      reply_instructions
    else
      raise ApplicationController::RoutingError
    end
  end

  private

  def reply_welcome
    reply_with_buttons(
      "Привет! Ознакомьтесь с правилами, чтобы продолжить.",
      [["Ознакомиться с правилами"]]
    )
  end

  def reply_rules
    reply_with_buttons(
      "Правила: 1. Не нарушайте. 2. Следуйте инструкциям.",
      [["Правила подтверждаю"]]
    )
  end

  def reply_instructions
    reply_with_buttons(
      "Подключим вам ВПН? Вот инструкции",
      Instructions.instance.titles.map { |title| [title] }
    )
  end
end