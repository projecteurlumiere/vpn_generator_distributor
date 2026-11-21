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

  def destroy(id)
    if key = current_user.keys_dataset.where(id: id).first # make sure you check user's keys only
      reply("🫡 Принимаемся удалять ключ #{key.name}", reply_markup: nil)
    else
      reply("🤔 Ошибка удаления ключа: не получилось найти ключ. Возможно, он уже удалён?", reply_markup: nil)
      return
    end

    if key && (res = key.destroy)
      msg = case res
            in :pending_destroy
              msg = "⏳ Ключ #{key.name} в процессе удаления"
            in Key
              msg = "✅ Ключ #{key.name} удалён успешно"
            in false
              msg = "❌ Не получилось удалить ключ #{key.name}"
            end

      reply(msg, reply_markup: nil)
    end
  end

  private

  def user_keys
    keys = current_user.keys_dataset
                       .order(Sequel.desc(:created_at))
                       .all

    reply("У вас сейчас нет ключей", reply_markup: nil) and return if keys.none?

    msg = "Ваши ключи"

    actions = keys.map do |key|
      action_msg = [
        "#{key.keydesk_username}",
        "от #{key.created_at.strftime("%d-%m-%Y")}"
      ].join(" ")

      { action_msg => callback_name(KeysController, "destroy", key.id) }
    end

    res = reply_with_inline_buttons(msg, actions)
    reply_with_buttons("Выберите ключ для удаления выше (можно выбрать несколько)",
      [
        ["Вернуться в меню"]
      ]
    )
  end
end
