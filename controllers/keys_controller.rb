class KeysController < ApplicationController
  def call
    case message.text
    in "Управление ключами"
      index
    in "Новый ключ"
      new
    in "Удалить ключ"
      delete
    end
  end

  def index

    if current_user && (keys = current_user.keys) && keys.any?
      reply_with_keys_to_delete(keys, "Здесь можно удалить уже выданный ключ. Выберите ключ для удаления:")
    else
      reply_with_start_menu("У вас сейчас нет ключей")
    end
  end

  def new
    if current_user&.too_many_keys?
      reply_with_start_menu("У вас слишком много ключей. Если ключ утерян, вы можете удалить существующий и выдать себе новый.")
      return
    elsif (keydesk = Keydesk.where { n_keys < 250 }.first)
      User.create(tg_id: user_id) if current_user.nil?
      reply("Создаём конфигурационный файл или ссылку. Стоит подождать")
      config = keydesk.create_config(user: current_user, personal_note: "Hello, #{[1,2,3,4,5].sample}")
      reply_with_buttons("Вот ваш ключ для Outline:\n#{config["outline"]}",
        [
          ["Инструкция для Outline", "Всё понятно, спасибо"]
        ])
    else
      reply_with_start_menu("Извините, сейчас свободных мест нет.")
    end
  end

  def create
    reply("Эта команда не должна вызываться")
  end

  def delete(id)
    if current_user && (key = current_user.keys_dataset.where(id:).first)
      key.keydesk.delete_user(username: key.keydesk_username)
      key.destroy
      if (keys = current_user.keys) && keys.any?
        reply_with_keys_to_delete(keys, "Ключ #{key.personal_note} удалён успешно.\nВыберите ключ для удаления:")
      else
        current_user.destroy
        reply_with_start_menu("Все ключи удалены")
      end
    else
      reply_with_keys_to_delete(current_users.keys, "Не получилось удалить ключ. Выберите ключ для удаления:")
    end
  end

  private

  def reply_with_keys_to_delete(keys, message)
    reply_with_inline_buttons(
      message,
      keys.each_with_object({}) do |key, h|
        h[key.personal_note] = "key_delete_#{key.id}"
      end
    )

    reply_with_buttons(
      "Или выберите другое действие:",
      [
        ["Не хочу ничего удалять, спасибо"]
      ]
    )
  end
end
