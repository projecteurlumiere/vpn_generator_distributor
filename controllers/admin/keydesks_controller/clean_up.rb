# frozen_string_literal: true

module Admin::KeydesksController::CleanUp
  CLEANING_UP = Async::Semaphore.new(1)

  def usernames_to_destroy
    if CLEANING_UP.blocking?
      reply("Мёртвые души уже ищутся. Нужно подождать!")
      return
    end

    CLEANING_UP.async do
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

      results = tasks.map(&:wait)

      msg = usernames_to_destroy_msg(results)

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
  end

  def check_before_clean_up
    current_user.update(state: [self.class.name, "check_before_clean_up", "awaiting_name"].join("|"))
    reply("Введите имя ключницы")
  end

  def clean_up
    if CLEANING_UP.blocking?
      reply("Мёртвые душие уже удаляются. Нужно подождать!")
      return
    end

    CLEANING_UP.async do
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

      results = tasks.map(&:wait)
      msg = clean_up_finished_msg(results)
      reply_with_inline_buttons(msg, [admin_menu_inline_button], parse_mode: "Markdown")
    end
  rescue StandardError
    reply("Что-то пошло не так при удалении мёртвых душ.")
  end

  private

  def list_usernames_to_destroy
    if kd = Keydesk.first(name: message.text)
      rows = []
      kd.usernames_to_destroy.each_slice(2) do |username, last_visit|
        rows << "%-17s %-7s" % [username[0...17], last_visit]
      end

      header = "%-14s %-10s" % ["Имя", "Был в сети"]
      table = [header, *rows].join("\n")

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

  def usernames_to_destroy_msg(rows)
    header = "%-13s %3s %3s" % ["Имя", "ДУШ", "ВЫД"]
    table = [header, *rows].join("\n")

    <<~TXT
      Пользователи на удаление:

      - Имя: Имя ключницы
      - ДУШ: Мёртвые души
      - ВЫД: Выдано ключей

      ```
      #{table}
      ```
    TXT
  end

  def clean_up_finished_table(rows)
    header = "%-13s %5s %5s" % ["Имя", "ДУШ", "УДЛ"]
    table = [header, *rows].join("\n")

    <<~TXT
      Очистка завершена.

      - Имя: Ключница
      - ДУШ: Мёртвых душ найдено
      - УДЛ: Удалено успешно

      ```
      #{table}
      ```
    TXT
  end
end
