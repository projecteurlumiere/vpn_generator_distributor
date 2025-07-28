class StartController < ApplicationController
  def call
    if message.text == "Всё понятно, спасибо" || message.text == "Не хочу ничего удалять, спасибо"
      reply_with_buttons(
        "Не за что!",
        [
          ["Новый ключ", "Управление ключами"],
          ["Инструкции"]
        ]
      )
    elsif current_user
      reply_with_buttons(
        "Добро пожаловать снова",
        [
          ["Новый ключ", "Управление ключами"],
          ["Инструкции"]
        ]
      )
    else
      reply_with_buttons(
        "Добро пожаловать!",
        [
          ["Новый ключ", "Инструкции"]
        ]
      )
    end
  end
end
