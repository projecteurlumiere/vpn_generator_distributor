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
      current_user.update(state: nil)
      reply("Привет, администратор!")

      reply_with_inline_buttons("Возможные админские действия",
        [
          {
            "Посмотреть инструкции" => callback_name(Admin::InstructionsController, "instructions")
          },
          {
            "Инструкции-черновики" => callback_name(Admin::InstructionsController, "instructions_under_review")
          },
          {
            "Загрузить инструкцию" => callback_name(Admin::InstructionsController, "upload_instruction")
          },
          {
            "Управление ключницами" => callback_name(Admin::KeydesksController, "index")
          }
        ]
      )
    else
      raise ApplicationController::RoutingError
    end
  end
end
