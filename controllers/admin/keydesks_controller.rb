# frozen_string_literal: true

class Admin::KeydesksController < Admin::BaseController
  include Admin::KeydesksController::CleanUp
  include Admin::KeydesksController::CreateKeydesk
  include Admin::KeydesksController::UpdateKeydesk

  def call
    # [controller_name, state, substates]
    state = current_user.state_array

    case state.drop(1)
    in ["new_keydesk", *]
      create_keydesk(state)
    in ["edit_keydesk", *]
      update_keydesk(state)
    in ["check_before_clean_up", *]
      list_usernames_to_destroy
    else
      raise RoutingError
    end
  end

  def index
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
      max      = keydesk.max_keys
      "%-2s %-13s %3d %3d %3d" % [online, keydesk.name[0...13], n_in_db, n_total, max]
    end

    msg = index_msg(rows)

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

  def restart
    reply("Перезапускаем доступ к ключницам.")

    begin
      Keydesk::PROXY_SEMAPHORE.async do
        Keydesk.stop_proxies
        Keydesk.start_proxies
      end.wait
    rescue StandardError => e
      reply("Прокси не были перезапущены: выдача ключей недоступна.")
      raise
    end

    reply("Прокси перезапущены успешно")
    index
  end

  private

  def index_msg(rows)
    header = "%-2s %-13s %3s %3s %3s" % ["🌐", "Имя", "БД", "ВЫД", "MAX"]

    table = [header, *rows].join("\n")
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
  end
end
