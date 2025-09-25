# AdminController
#
# Commands:
# /admin instructions
#   - List all instruction sets (windows, mac, etc.)
# /admin upload_instruction
#   - YAML file to upload
# /admin versions
#   - Show git history
# /admin rollback <version>
#   - Go to a backup version
# /admin upload_images_for <instruction_name>
#   - Guided: per-step, prompt for file(s), save images by step.     
#
# Images: upload as files (not photos). Filenames preserved.
# Guided uploads link files to steps live; no post-facto missing check needed.
# All changes git-versioned. Only track state during guided sessions.

class Admin::KeydesksController < ApplicationController
  include AdminHelpers

  def self.routes
    []
  end

  def call
    state = current_user.state_array

    case state
    in [_, "new_keydesk", *]
      create_keydesk(state)
    in [_, "edit_keydesk", *]
      update_keydesk(state)
    else
      raise RoutingError
    end
  end

  def index
    header = "%-2s %-13s %3s %3s %3s" % ["🌐", "Имя", "БД", "ВЫД", "MAX"]

    rows = Keydesk.all.map do |keydesk|
      online   = keydesk.online ? "🟢" : "🔴"
      n_in_db  = keydesk.keys_dataset.count
      n_total  = keydesk.n_keys
      soft_max = keydesk.max_keys
      "%-2s %-13s %3d %3d %3d" % [online, keydesk.name[0..6], n_in_db, n_total, soft_max]
    end

    table = ([header] + rows).join("\n")
    msg = <<~TXT
      Ключницы:

      - 🌐: Онлайн
      - Имя: Имя
      - БД: В базе
      - ВЫД: Выдано
      - MAX: Макс (<= 250)

      ```
      #{table}
      ```
    TXT

    reply_with_inline_buttons(msg, [
        admin_menu_inline_button,
        {
          "Добавить ключницу" => callback_name("new")
        },
        {
          "Изменить" => callback_name("edit")
        },
        {
          "Перезапустить ключницы" => callback_name("restart")
        },
      ],
      parse_mode: "Markdown"
    )
  end

  def new
    current_user.update(state: [self.class.name, "new_keydesk", "name"].join("|"))
    reply("Введите имя ключницы")
  end

  def edit
    current_user.update(state: [self.class.name, "edit_keydesk", "name"].join("|"))
    reply("Введите имя ключницы")
  end

  def restart
    reply("Перезапускаем доступ к ключницам. Бот будет недоступен во время ожидания")

    begin
      $mutex.sync { Keydesk.start_proxies }
    rescue StandardError
      reply("Прокси не были перезапущены: выдача ключей недоступна.")
    end

    reply("Прокси перезапущены успешно")
    index
  end

  private

  def create_keydesk(state)
    msg = message.text.strip
    
    case state
    in [_, _, "name", *] if Keydesk.first(name: msg)
      reply("Ключница с таким именем уже существует")
    in [_, _, "name", *] if msg.size > 13
      reply("Имя ключницы не должно превышать 13 символов")
    in [_, _, "name", *]
      new_state = state << msg
      new_state[2] = "max_keys"
      current_user.update(state: new_state.join("|"))
      reply("Введите максимальное число пользователей для ключницы (целое число)")
    in [_, _, "max_keys", *] unless msg.match?(/\A\d/)
      reply("Укажите целое число")
    in [_, _, "max_keys", *] if msg.to_i > Keydesk::MAX_USERS
      reply("Число не должно превышать #{Keydesk::MAX_USERS}")
    in [_, _, "max_keys", *]
      new_state = state << msg
      new_state[2] = "ss_link"
      current_user.update(state: new_state.join("|"))
      reply("Отправьте ссылку для подключения к ключнице")
    in [_, _, "ss_link", *] if Keydesk.first(ss_link: msg)
      reply("Ключница с такой ссылкой уже существует")
    in [_, _, "ss_link", name, max_keys]
      Keydesk.create(name:, max_keys:, ss_link: msg)
      current_user.update(state: nil)
      reply("Ключница добавлена")
      self.restart
    else
      raise RoutingError
    end 
  end

  def update_keydesk(state)
    msg = message.text.strip

    case state
    in [_, _, "name", *] if (kd = Keydesk.first(name: msg))
      new_state = state << kd.id
      new_state[2] = "menu"
      current_user.update(state: new_state.join("|"))
      reply_with_buttons("Доступные действия для ключницы `#{msg}`:",[
        ["Изменить имя или число ключей"],
        (["Удалить"] if kd.keys_dataset.count == 0)
      ].compact)
    in [_, _, "name", *]
      reply("Нет такой ключницы")
    in [_, _, "menu", *] if msg == "Удалить"
      Keydesk.first(id: state[3]).destroy
      reply("Ключница удалена")
      self.current_user.update(state: nil)
      self.restart
    in [_, _, "menu", *] if msg == "Изменить имя или число ключей"
      new_state = state.dup
      new_state[2] = "edit_name"
      current_user.update(state: new_state.join("|"))

      reply_with_buttons("Введите новое имя", [["Оставить прежнее"]])
    in [_, _, "edit_name", *] if msg == "Оставить прежнее"
      new_state = state.dup
      new_state[2] = "edit_max_keys"
      current_user.update(state: new_state.join("|"))

      reply_with_buttons("Введите новое максимальное число пользователей для ключницы (целое число)", [["Оставить прежнее"]])
    in [_, _, "edit_name", *] if msg.size > 13
      reply("Новое имя не может быть длиннее 13 символов.", reply_markup: nil)
    in [_, _, "edit_name", *] if (kd = Keydesk.first(name: msg))
      reply("Такое имя уже занято", reply_markup: nil)
    in [_, _, "edit_name", *]
      Keydesk.first(id: state[3]).update(name: msg, online: false)
      reply("Имя обновлено")

      new_state = state.dup
      new_state[2] = "edit_max_keys"

      current_user.update(state: new_state.join("|"))
      reply_with_buttons("Введите новое максимальное число пользователей для ключницы (целое число)", [["Оставить прежнее"]])
    in [_, _, "edit_max_keys", *] if msg == "Оставить прежнее"
      reply("Редактирование окончено")
      current_user.update(state: nil)
      index
    in [_, _, "edit_max_keys", *] unless msg.match?(/\A\d/)
      reply("Введите целое число", reply_markup: nil)
    in [_, _, "edit_max_keys", *] if msg.to_i > Keydesk::MAX_USERS
      reply("Число не должно превышать #{Keydesk::MAX_USERS}", reply_markup: nil)
    in [_, _, "edit_max_keys", *]
      Keydesk.first(id: state[3]).update(max_keys: msg)
      reply("Максимальное число ключей обновлено")
      reply("Редактирование окончено")
      current_user.update(state: nil)
      index
    else
      raise RoutingError
    end
  end
end
