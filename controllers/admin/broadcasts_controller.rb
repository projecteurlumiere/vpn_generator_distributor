# frozen_string_literal: true

class Admin::BroadcastsController < Admin::BaseController
  IS_BROADCASTING = Async::Semaphore.new(1)

  def call
    raise RoutingError unless current_user.state_array in [^(self.class.name), "awaiting"]

    case message.text
    in "Отменить рассылку"
      current_user.update(state: nil)
      msg = <<~TXT
        Отредактировать сообщение для рассылки можно в меню слайдов - файл broadcast.yml

        /admin, чтобы вернуться в меню
      TXT

      reply(msg)
    in "Разослать" if IS_BROADCASTING.blocking?
      reply("Рассылка уже проводится. Нужно подождать")
    in "Разослать"
      IS_BROADCASTING.async { broadcast }
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
                  .where { chat_id !~ nil }
                  .distinct
                  .select_map(:chat_id)

    chat_ids.each do |id|
      reply(text, photos:, chat_id: id)
    end

    msg = <<~TXT
      Рассылка завершена успешно.
      Пользователей, получивших сообщение: #{chat_ids.size}.

      /admin, чтобы вернуться к другим делам.
    TXT

  rescue StandardError => e
    LOGGER.error("Broadcast failed: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
    reply("Сообщение не было разослано всем: #{e.class}.")
  end
end
