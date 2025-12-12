class Admin::KeydesksController < Admin::BaseController
  def call
    state = current_user.state_array

    case state
    in [_, "new_keydesk", *]
      create_keydesk(state)
    in [_, "edit_keydesk", *]
      update_keydesk(state)
    in [_, "check_before_clean_up", *]
     list_usernames_to_destroy
    else
      raise RoutingError
    end
  end

  def index
    header = "%-2s %-13s %3s %3s %3s" % ["🌐", "Имя", "БД", "ВЫД", "MAX"]

    rows = Keydesk.all.map do |keydesk|
      online   = case keydesk.status
                 in :online
                   "🟢"
                 in :unstable
                   "🟡"
                 in :offline
                   "🔴"
                 end
      n_in_db  = keydesk.keys_dataset.count
      n_total  = keydesk.n_keys
      soft_max = keydesk.max_keys
      "%-2s %-13s %3d %3d %3d" % [online, keydesk.name[0...13], n_in_db, n_total, soft_max]
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
          "Обновить" => callback_name("refresh")
        },
        {
          "Новая ключница" => callback_name("new")
        },
        {
          "Настроить ключницу" => callback_name("edit")
        },
        {
          "\"Мёртвые души\"" => callback_name("usernames_to_destroy")
        },
        {
          "Перезапустить ключницы" => callback_name("restart")
        },
      ],
      parse_mode: "Markdown"
    )
  end

  alias_method :refresh, :index

  def new
    current_user.update(state: [self.class.name, "new_keydesk", "name"].join("|"))
    reply("Введите имя ключницы")
  end

  def edit
    current_user.update(state: [self.class.name, "edit_keydesk", "name"].join("|"))
    reply("Введите имя ключницы")
  end

  def restart
    reply("Перезапускаем доступ к ключницам.")

    begin
      Bot::MUTEX.sync do
        Keydesk.stop_proxies
        Keydesk.start_proxies
      end
    rescue StandardError => e
      reply("Прокси не были перезапущены: выдача ключей недоступна.")
      raise
    end

    reply("Прокси перезапущены успешно")
    index
  end

  def usernames_to_destroy
    reply("Мёртвые душие уже удаляются. Нужно подождать!") and return if @@cleaning_up

    header = "%-13s %3s %3s" % ["Имя", "ДУШ", "ВЫД"]

    tasks = Keydesk.all.map do |kd|
      Async do
        kd.find_usernames_to_destroy!

        "%-13s %3s %3s" % [
          kd.name[0...13],
          kd.usernames_to_destroy.size / 2,
          kd.n_keys
        ]
      end
    end

    rows = tasks.map(&:wait)

    table = ([header] + rows).join("\n")
    msg = <<~TXT
      Пользователи на удаление:

      - Имя: Имя ключницы
      - ДУШ: Мёртвые души
      - ВЫД: Выдано ключей

      ```
      #{table}
      ```
    TXT

    reply_with_inline_buttons(msg, [
      admin_menu_inline_button,
      {
        "Проверить" => callback_name("check_before_clean_up")
      },
      {
        "Очистить" => callback_name("clean_up")
      }
    ], parse_mode: "Markdown")
  end

  def check_before_clean_up
    current_user.update(state: [self.class.name, "check_before_clean_up", "awaiting_name"].join("|"))
    reply("Введите имя ключницы")
  end

  def clean_up
    reply("Мёртвые души уже удаляются. Нужно подождать!") and return if @@cleaning_up

    @@cleaning_up = true
    reply("Удаляем \"мёртвые души\". Это займёт время")

    tasks = Keydesk.all.map do |kd|
      Async do
        "%-13s %5d %5d" % [
          kd.name[0...13],
          kd.usernames_to_destroy.size / 2,
          kd.clean_up_keys.count { it == true }
        ]
      end
    end

    rows = tasks.map(&:wait)

    header = "%-13s %5s %5s" % ["Имя", "ДУШ", "УДЛ"]
    table = ([header] + rows).join("\n")

    msg = <<~TXT
      Очистка завершена.

      - Имя: Ключница
      - ДУШ: Мёртвых душ найдено
      - УДЛ: Удалено успешно

      ```
      #{table}
      ```
    TXT

    reply_with_inline_buttons(msg, [admin_menu_inline_button], parse_mode: "Markdown")
  rescue StandardError
    reply("Что-то пошло не так при удалении мёртвых душ.")
  ensure
    @@cleaning_up = false
  end

  private

  def create_keydesk(state)
    msg = message.text.strip

    case state.drop(2)
    in ["name", *] if Keydesk.first(name: msg)
      reply("Ключница с таким именем уже существует")
    in ["name", *] if msg.size > 13
      reply("Имя ключницы не должно превышать 13 символов")
    in ["name", *]
      new_state = state << msg
      new_state[2] = "max_keys"
      current_user.update(state: new_state.join("|"))
      reply("Введите максимальное число пользователей для ключницы (целое число)")
    in ["max_keys", *] unless msg.match?(/\A\d/)
      reply("Укажите целое число")
    in ["max_keys", *] if msg.to_i > Keydesk::MAX_USERS
      reply("Число не должно превышать #{Keydesk::MAX_USERS}")
    in ["max_keys", *]
      new_state = state << msg
      new_state[2] = "ss_link"
      current_user.update(state: new_state.join("|"))
      reply("Отправьте ссылку для подключения к ключнице")
    in ["ss_link", *] if Keydesk.first(ss_link: msg)
      reply("Ключница с такой ссылкой уже существует")
    in ["ss_link", name, max_keys]
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

    case state.drop(2)
    in ["name", *] if (kd = Keydesk.first(name: msg))
      new_state = state << kd.id
      new_state[2] = "menu"
      current_user.update(state: new_state.join("|"))
      reply_with_buttons("Доступные действия для ключницы `#{msg}`:",[
        ["Изменить имя или число ключей"],
        (["Удалить"] if kd.keys_dataset.count == 0)
      ].compact)
    in ["name", *]
      reply("Нет такой ключницы")
    in ["menu", *] if msg == "Удалить"
      new_state = state.dup
      new_state[2] = "destroy_confirm"

      kd = Keydesk.first(id: state[3])
      current_user.update(state: new_state.join("|"))
      reply_with_buttons(
        "Точно ли вы хотите удалить ключницу #{kd.name}?\nВсе записи о ключах в базе данных бота будут удалены!", 
        [["Да, удалить", "Нет, не удалять"]]
      )
    in ["destroy_confirm", *] if msg == "Да, удалить"
      kd = Keydesk[state[3]] 
      kd.keys_dataset.delete
      kd.destroy
      reply("Ключница #{kd.name} удалена")
      current_user.update(state: nil)
      restart
    in ["destroy_confirm", *] if msg == "Нет, не удалять"
      current_user.update(state: nil)
      index
    in ["menu", *] if msg == "Изменить имя или число ключей"
      new_state = state.dup
      new_state[2] = "edit_name"
      current_user.update(state: new_state.join("|"))

      reply_with_buttons("Введите новое имя", [["Оставить прежнее"]])
    in ["edit_name", *] if msg == "Оставить прежнее"
      new_state = state.dup
      new_state[2] = "edit_max_keys"
      current_user.update(state: new_state.join("|"))

      reply_with_buttons("Введите новое максимальное число пользователей для ключницы (целое число)", [["Оставить прежнее"]])
    in ["edit_name", *] if msg.size > 13
      reply("Новое имя не может быть длиннее 13 символов.", reply_markup: nil)
    in ["edit_name", *] if (kd = Keydesk.first(name: msg))
      reply("Такое имя уже занято", reply_markup: nil)
    in ["edit_name", *]
      Keydesk.first(id: state[3]).update(name: msg)
      reply("Имя обновлено")

      new_state = state.dup
      new_state[2] = "edit_max_keys"

      current_user.update(state: new_state.join("|"))
      reply_with_buttons("Введите новое максимальное число пользователей для ключницы (целое число)", [["Оставить прежнее"]])
    in ["edit_max_keys", *] if msg == "Оставить прежнее"
      reply("Редактирование окончено")
      current_user.update(state: nil)
      index
    in ["edit_max_keys", *] unless msg.match?(/\A\d/)
      reply("Введите целое число", reply_markup: nil)
    in ["edit_max_keys", *] if msg.to_i > Keydesk::MAX_USERS
      reply("Число не должно превышать #{Keydesk::MAX_USERS}", reply_markup: nil)
    in ["edit_max_keys", *]
      Keydesk.first(id: state[3]).update(max_keys: msg)
      reply("Максимальное число ключей обновлено")
      reply("Редактирование окончено")
      current_user.update(state: nil)
      index
    else
      raise RoutingError
    end
  end

  def list_usernames_to_destroy
    if kd = Keydesk.first(name: message.text)
      rows = []
      kd.usernames_to_destroy.each_slice(2) do |username, last_visit|
        rows << "%-17s %-7s" % [username[0...17], last_visit]
      end

      header = "%-14s %-10s" % ["Имя", "Был в сети"]
      table = ([header] + rows).join("\n")

      msg = <<~TXT
        Пользователи на удаление из ключницы #{kd.name}:

        ```
        #{table}
        ```
      TXT

      reply(msg, parse_mode: "Markdown")
    else
      reply("Ключница не найдена.")
    end
  end
end
