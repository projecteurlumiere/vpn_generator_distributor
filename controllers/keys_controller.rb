# frozen_string_literal: true

class KeysController < ApplicationController
  def self.routes
    [
      "Удалить ключ", "Удалить ключи"
    ]
  end

  def call
    current_user.update(state: nil)

    case message.text
    in "Удалить ключ" | "Удалить ключи"
      user_keys
    else
      raise RoutingError
    end
  end

  def destroy(id, emoji)
    if key = current_user.keys_dataset.where(id: id).first # make sure you check user's keys only
      edit_message("Удаляем ключ #{emoji} #{key.name}")
    else
      edit_message("🤔 Ошибка удаления ключа: не получилось найти ключ. Возможно, он уже удалён?")
      return
    end

    if key && (res = key.destroy)
      msg = case res
            in :pending_destroy
              "⏳ Ключ #{emoji} #{key.name} уже в процессе удаления. Если что-то сломалось, попробуйте позже или свяжитесь с поддержкой через меню /start"
            in Key
              "✅ Ключ #{emoji} #{key.name} удалён успешно"
            in false
              "❌ Не получилось удалить ключ #{emoji} #{key.name}"
            end

      edit_message(msg)
    end
  end

  private

  def user_keys
    keys = current_user.keys_dataset
                       .order(Sequel.desc(:created_at))
                       .all

    reply("У вас сейчас нет ключей", reply_markup: nil) and return if keys.none?

    reply("*Ваши ключи:*", reply_markup: nil)

    breakpoints = %w[🦊 🐘 🌵 🚀 🎩 🐢 📚 🦉 🍇 🛹].shuffle
    keys.each do |key|
      action_msg = breakpoints.pop

      msg = [
        action_msg,
        "#{key.keydesk_username}",
        "от #{key.created_at.strftime("%d-%m-%Y")}"
      ].join("\n")
      action = { "Удалить #{action_msg}" => callback_name(KeysController, "destroy", key.id, action_msg) }

      res = reply_with_inline_buttons(msg, action, parse_mode: "Markdown")
      Edit.schedule(payload: { text: "Это сообщение было удалено: оно более не актуально." }, chat_id:, message_id: res.message_id)
    end

    reply_with_buttons("Выберите ключ для удаления выше (можно выбрать несколько)",
      [
        ["Вернуться в меню"]
      ]
    )
  end
end
