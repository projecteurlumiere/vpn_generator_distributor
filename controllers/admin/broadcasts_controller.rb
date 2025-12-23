class Admin::BroadcastsController < Admin::BaseController
  @@broadcasting = false

  def call
    raise RoutingError unless current_user.state_array in [^(self.class.name), "awaiting"]

    current_user.update(state: nil)

    case message.text
    in "Отменить рассылку"
      msg = <<~TXT
        Отредактировать сообщение для рассылки можно в меню слайдов - файл broadcast.yml

        /admin, чтобы вернуться в меню
      TXT

      reply(msg)
    in "Разослать" if @@broadcasting
      reply("Рассылка уже проводится. Нужно подождать")
    in "Разослать"
      broadcast
    else
      raise RoutingError
    end
  end

  def menu
    current_user.update(state: "#{self.class.name}|awaiting")
    slide = Slides.instance[:broadcast]
    reply_with_buttons(slide[:text], [
      ["Разослать", "Отменить рассылку"]
    ], photos: slide[:images])
  end

  private

  def broadcast
    @@broadcasting = true

    current_user.update(state: nil)

    reply(<<~TXT
      Начинаем рассылку. Это займёт время.

      /admin, чтобы заняться другими делами.
      TXT
    )

    text = Slides.instance[:broadcast][:text]
    photos = Slides.instance[:broadcast][:images]
    chat_ids = Key.join(:users, id: :user_id)
                  .select(:users__chat_id)
                  .distinct
                  .select_map(:chat_id)

    chat_ids.each do |id|
      reply(text, photos:, chat_id: id)
    end

    reply(
      <<~TXT
        Рассылка завершена успешно.
        Пользователей, получивших сообщение: #{chat_ids.size}.

        /admin, чтобы вернуться к другим делам.
      TXT
    )

  rescue StandardError => e
    LOGGER.error("Broadcast failed: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
    reply("Сообщение не было разослано всем: #{e.class}.")
  ensure
    @@broadcasting = false
  end
end
