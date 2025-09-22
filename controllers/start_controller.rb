class StartController < ApplicationController
  def self.routes
    [
      "/start", "Вернуться в меню",
      "Ознакомиться с правилами", "Правила", 
      "Правила подтверждаю",
      "О проекте"
    ]
  end

  def call
    current_user.update(state: nil)

    case message.text
    in ("/start" | "Вернуться в меню") if current_user.rules_read
      reply_menu
    in "/start"
      reply_welcome
    in "Ознакомиться с правилами" | "Правила"
      reply_rules
    in "Правила подтверждаю"
      current_user.update(rules_read: true)
      reply_menu
    in "О проекте"
      reply_about
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

  def reply_menu
    reply_with_buttons(
      "Доступны следующие действия:",
      [
        ["Подключить VPN"],
        ["Правила"],
        ["О проекте"]
      ]
    )
  end

  def reply_about
    reply_with_buttons(
      "Надеемся наша работа будет для вас полезной. Мы делаем важное дело!",
      [
        ["Вернуться в меню"]
      ]
    )
  end
end
