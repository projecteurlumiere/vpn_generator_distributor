# frozen_string_literal: true

class StartController < ApplicationController
  def self.routes
    [
      "/start", "Вернуться в меню",
      "Ознакомиться с правилами", "Прочитать правила",
      "Перейти к меню",
      "Узнать о проекте",
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
    in "Ознакомиться с правилами" | "Прочитать правила"
      reply_slide(:about)
    in "Перейти к меню"
      current_user.update(rules_read: true)
      reply_menu
    in "Узнать о проекте"
      reply_slide(:about)
    in "/tg_id"
      reply("`#{tg_id}`", parse_mode: "Markdown", reply_markup: nil)
    in "/my_id"
      reply("`#{current_user.id}`", parse_mode: "Markdown", reply_markup: nil)
    else
      raise RoutingError
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
      [["Узнать о проекте"]]
    )
  end

  def reply_menu
    reply_with_buttons(
      "Что вы хотите сделать?\nВыберите действие внизу",
      [
        ["Подключить VPN"],
        ["Прочитать правила"],
        ["Узнать о проекте"],
        ["Написать в поддержку"]
      ].compact
    )
  end
end
