class KeysController < ApplicationController
  def self.routes
    []
  end

  def call
    case message.text
    in "Управление ключами"
      index
    in "Новый ключ"
      create
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

  def create
    if current_user&.too_many_keys?
      reply_with_start_menu("У вас слишком много ключей. Если ключ утерян, вы можете удалить существующий и выдать себе новый.")
    elsif current_user&.awaiting_config?
      reply("Мы уже выдаём вам ключ. Пожалуйста, подождите.\nЕсли вы потерялись, нажмите /start")
    else
      reply("Добавляем вас в нашу сеть и создаём файлы.\nПожалуйста, подождите. Если вы уверены, что что-то пошло не так, нажмите /start")
      User.create(tg_id: user_id) if current_user.nil?
      res = Key.issue(to: current_user) 
      case res
      in :keydesks_full
        reply_with_start_menu("Извините, сейчас свободных мест нет.")
      in :keydesks_error
        reply_with_start_menu("Что-то пошло во время создания конфигурации. Попробуйте ещё раз или позже.")
      in Key
        config = res.config
        reply("Вот ваш ключ для Outline - скопируйте его целиком:")
        reply("#{config["outline"]}")
        upload_file(config["wireguard"], "Ваш конфигурационный файл для Wireguard")
        upload_file(config["amnezia"], "Ваш конфигурационный файл для Amnezia")
        reply_with_buttons("Используйте один из трёх ключей сверху.\nНикогда не пользуйтесь ими одновременно", [
          ["Инструкция для Outline", "Инструкция для Amnezia", "Инструкция для Wireguard"], 
          ["Всё понятно, спасибо"]
        ])
      end
    end
  ensure
    if config
      File.delete(config["wireguard"])
      File.delete(config["amnezia"])
    end
  end

  def delete(id)
    if current_user && (key = current_user.keys_dataset.where(id:).first)
      if key.awaiting_destroy?
        reply_with_keys_to_delete(current_user.keys, "Ключ #{key.personal_note} находится в процессе удаления")
        return
      else
        reply("Удаляем ключ #{key.personal_note}.\nНадо подождать. Если что-то пошло не так, нажмите /start")
        key.destroy
      end
      
      if (keys = current_user.keys) && keys.any?
        reply_with_keys_to_delete(keys, "Ключ #{key.personal_note} удалён успешно.\nВыберите ключ для удаления:")
      else
        current_user.destroy
        reply_with_start_menu("Все ключи удалены")
      end
    elsif current_user
      reply_with_keys_to_delete(current_user.keys, "Не получилось удалить ключ. Выберите ключ для удаления:")
    else
      reply_with_start_menu("Этот ключ нельзя удалить.")
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

  def upload_file(path, message)
    file = File.open(path)
    upload = Faraday::UploadIO.new(file, "text/plain", File.basename(file))
    
    bot.api.send_document(
      chat_id: chat_id,
      document: upload,
      caption: message
    )
    file.close
  end
end
