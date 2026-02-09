# frozen_string_literal: true

class Admin::MenuController < Admin::BaseController
  def self.routes
    [
      "/admin"
    ]
  end

  def call
    case message.text
    in "/admin"
      menu
    else
      raise ApplicationController::RoutingError
    end
  end

  def menu
    current_user.update(state: nil)

    reply("Привет администратор!")

    stats = %x[./scripts/server_metrics.sh].strip.split("\n")
    rows = stats.map do |line|
      metric, value = line.split(":", 2)
      "%-7s %-17s" % [metric.to_s.strip[0,7], value.to_s.strip[0,16]]
    end

    msg = <<~TXT
      Выберите действие из предложенных ниже.

      Статус сервера:
      ```
      #{rows.join("\n")}
      ```
    TXT

    reply_with_inline_buttons(msg,
      [
        {
          "Управление инструкциями" => callback_name(Admin::InstructionsController, "menu")
        },
        {
          "Управление слайдами" => callback_name(Admin::SlidesController, "menu")
        },
        {
          "Рассылка" => callback_name(Admin::BroadcastsController, "menu")
        },
        {
          "Управление ключницами" => callback_name(Admin::KeydesksController, "index")
        },
        {
          "Управление пользователем" => callback_name(Admin::UsersController, "find_user")
        }
      ], parse_mode: "Markdown"
    )
  end
end
