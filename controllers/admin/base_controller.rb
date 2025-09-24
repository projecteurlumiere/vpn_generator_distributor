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

class Admin::BaseController < ApplicationController
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
          "Управление инструкциями" => callback_name(Admin::InstructionsController, "admin_menu")
        },
        {
          "Управление ключницами" => callback_name(Admin::KeydesksController, "index")
        }
      ]
    )
  end
end
