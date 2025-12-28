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
    reply("Привет, администратор!")

    reply_with_inline_buttons("Возможные админские действия",
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
      ]
    )
  end
end
