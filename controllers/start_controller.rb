class StartController < ApplicationController
  def call

    if message.text.match?(/Спасибо/i)
      reply_with_start_menu("Не за что!")
    elsif current_user
      reply_with_start_menu("Добро пожаловать снова!")
    else
      reply_with_start_menu("Добро пожаловать!")
    end
  end
end
