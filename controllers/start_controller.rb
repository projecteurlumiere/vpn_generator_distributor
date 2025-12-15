class StartController < ApplicationController
  def self.routes
    [
      "/start", "Вернуться в меню",
      "Ознакомиться с правилами", "Правила",
      "Принимаю правила",
      "О проекте",
      "/my_id", "/tg_id"
    ]
  end

  def call
    current_user.update(state: nil)

    case message.text
    in ("/start" | "Вернуться в меню") if current_user.rules_read
      reply_menu
    in "/start" | "Вернуться в меню"
      reply_welcome
    in "Ознакомиться с правилами" | "Правила"
      reply_rules
    in "Принимаю правила"
      current_user.update(rules_read: true)
      reply_menu
    in "О проекте"
      reply_about
    in "/tg_id"
      reply("`#{tg_id}`", parse_mode: "Markdown", reply_markup: nil)
    in "/my_id"
      reply("`#{current_user.id}`", parse_mode: "Markdown", reply_markup: nil)
    else
      raise ApplicationController::RoutingError
    end
  end

  private

  def reply_welcome
    msg = <<~TXT
      Привет!

      Для навигации в боте используйте кнопки. Они находятся внизу, возле поля ввода сообщения.

      Чтобы продолжить, ознакомьтесь с правилами.
    TXT

    reply_with_buttons(
      msg,
      [["Ознакомиться с правилами"]]
    )
  end

  def reply_rules
    reply_slide(:rules)
  end

  def reply_menu
    reply_with_buttons(
      "Выберите действие из предложенных",
      [
        ["Подключить VPN"],
        ["Правила"],
        ["О проекте"],
        ["Написать в поддержку"]
      ].compact
    )
  end

  def reply_about
    reply_slide(:about)
  end
end
